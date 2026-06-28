#!/usr/bin/env python3
"""
mocha_lsp.py — Mocha Language Server Protocol server
Speaks JSON-RPC over stdin/stdout.
Start: python mocha_lsp.py
VS Code connects via the extension (later); for now test with direct stdin.
"""

import sys
import json
import threading
import subprocess
import tempfile
import os
import time
from pathlib import Path

# ── Constants ──────────────────────────────────────────────────────────────────

SERVER_NAME    = "mocha-lsp"
SERVER_VERSION = "0.1.0"

# Path to your Mocha compiler entry point
MOCHA_COMPILER = Path(__file__).parent / "mocha_compile.py"

# ── Transport: read/write JSON-RPC over stdin/stdout ──────────────────────────
# Protocol: "Content-Length: N\r\n\r\n" followed by N bytes of UTF-8 JSON.
# This is the raw LSP wire format — same as what VS Code sends.

def read_message(stream) -> dict | None:
    """Read one LSP message from stream. Returns parsed dict or None on EOF."""
    # Read headers until blank line
    headers = {}
    while True:
        line = stream.readline()
        if not line:
            return None  # EOF
        line = line.decode("utf-8").rstrip("\r\n")
        if line == "":
            break  # blank line = end of headers
        if ":" in line:
            key, _, val = line.partition(":")
            headers[key.strip()] = val.strip()

    length = int(headers.get("Content-Length", 0))
    if length == 0:
        return None

    body = stream.read(length)
    return json.loads(body.decode("utf-8"))


def write_message(stream, msg: dict):
    """Write one LSP message to stream."""
    body = json.dumps(msg, ensure_ascii=False).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("utf-8")
    stream.write(header + body)
    stream.flush()


# ── Diagnostics: run Mocha compiler on a file, parse errors ───────────────────
# We write the document text to a temp file, invoke the compiler,
# and parse its stderr for error lines.
#
# ADJUST parse_compiler_output() to match your actual compiler error format.
# Current assumed format:  "filename:line:col: error: message"
# or:                      "MochaError (file.mch, line N): message"

def run_mocha_compiler(source_text: str, uri: str) -> list[dict]:
    """
    Write source to a temp .mch file, run the Mocha compiler on it,
    return a list of LSP Diagnostic dicts.
    """
    diagnostics = []

    if not MOCHA_COMPILER.exists():
        # Compiler not found — return a single warning so you can see it working
        return [{
            "range": make_range(0, 0, 0, 0),
            "severity": 2,  # Warning
            "source": "mocha-lsp",
            "message": f"Mocha compiler not found at: {MOCHA_COMPILER}"
        }]

    # Write to temp file
    with tempfile.NamedTemporaryFile(
        suffix=".mch", mode="w", encoding="utf-8", delete=False
    ) as f:
        f.write(source_text.replace('\r\n', '\n'))  # normalize to Unix line endings
        tmp_path = f.name

    try:
        result = subprocess.run(
            [sys.executable, str(MOCHA_COMPILER), tmp_path, "--check-only"],
            capture_output=True,
            text=True,
            timeout=15,
            encoding='utf-8',
            cwd=str(MOCHA_COMPILER.parent)
        )
        stderr = (result.stdout or "") + (result.stderr or "")  # some compilers mix these

        diagnostics = parse_compiler_output(stderr)

    except subprocess.TimeoutExpired:
        diagnostics = [{
            "range": make_range(0, 0, 0, 0),
            "severity": 1,
            "source": "mocha-lsp",
            "message": "Mocha compiler timed out"
        }]
    except Exception as e:
        diagnostics = [{
            "range": make_range(0, 0, 0, 0),
            "severity": 1,
            "source": "mocha-lsp",
            "message": f"mocha-lsp internal error: {e}"
        }]
    finally:
        os.unlink(tmp_path)

    return diagnostics


def parse_compiler_output(output: str) -> list[dict]:
    import re
    diagnostics = []
    seen = set()

    PAT_MOCHA = re.compile(
        r"(Mocha\w+Error)\s+at\s+line\s+(\d+),\s*col\s+(\d+):\s*(.+)"
    )
    PAT_MOCHA_NONCOL = re.compile(
        r"(Mocha\w+Error)\s+at\s+line\s+(\d+):\s*(.+)"
    )
    PAT_MOCHA_NOLOC = re.compile(
        r"(Mocha\w+Error):\s*(.+)"
    )

    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue

        m = PAT_MOCHA.search(line)
        if m:
            kind   = m.group(1)
            lineno = max(0, int(m.group(2)) - 1)
            col    = max(0, int(m.group(3)) - 1)
            msg    = m.group(4).strip()
            diag = {
                "range":    make_range(lineno, col, lineno, 999),
                "severity": 1,
                "source":   "mocha",
                "message":  f"{kind}: {msg}"
            }
        elif (m := PAT_MOCHA_NONCOL.search(line)):
            kind   = m.group(1)
            lineno = max(0, int(m.group(2)) - 1)
            msg    = m.group(3).strip()
            diag = {
                "range":    make_range(lineno, 0, lineno, 999),
                "severity": 1,
                "source":   "mocha",
                "message":  f"{kind}: {msg}"
            }
        elif (m := PAT_MOCHA_NOLOC.search(line)):
            kind = m.group(1)
            msg  = m.group(2).strip()
            diag = {
                "range":    make_range(0, 0, 0, 0),
                "severity": 1,
                "source":   "mocha",
                "message":  f"{kind}: {msg}"
            }
        else:
            continue

        key = (diag["range"]["start"]["line"], diag["message"])
        if key not in seen:
            seen.add(key)
            diagnostics.append(diag)

    return diagnostics


def make_range(start_line, start_char, end_line, end_char) -> dict:
    return {
        "start": {"line": start_line, "character": start_char},
        "end":   {"line": end_line,   "character": end_char}
    }


# ── Server state ───────────────────────────────────────────────────────────────

class MochaLSP:
    def __init__(self):
        self.documents: dict[str, str] = {}   # uri -> current text
        self.shutdown_flag = False
        # Debounce: map uri -> (timer, version) so we don't recompile on every keystroke
        self._debounce_timers: dict[str, threading.Timer] = {}
        self._debounce_delay = 0.4  # seconds

    # ── Message dispatch ───────────────────────────────────────────────────────

    def handle(self, msg: dict):
        method = msg.get("method", "")
        msg_id = msg.get("id")

        handler = {
            "initialize":                    self.on_initialize,
            "initialized":                   self.on_initialized,
            "shutdown":                      self.on_shutdown,
            "exit":                          self.on_exit,
            "textDocument/didOpen":          self.on_did_open,
            "textDocument/didChange":        self.on_did_change,
            "textDocument/didClose":         self.on_did_close,
            "textDocument/didSave":          self.on_did_save,
        }.get(method)

        if handler:
            handler(msg)
        elif msg_id is not None:
            # Unknown request (has id) — send empty result so VS Code doesn't hang
            self.send_response(msg_id, result=None)
        # Notifications (no id) we don't know: silently ignore

    # ── Lifecycle ──────────────────────────────────────────────────────────────

    def on_initialize(self, msg: dict):
        self.send_response(msg["id"], result={
            "capabilities": {
                # Full document sync — send entire file on every change
                # (incremental sync is an optimization for later)
                "textDocumentSync": 1,
                # We'll add more capabilities here as we build them:
                # "hoverProvider": True,
                # "completionProvider": {"triggerCharacters": [".", " "]},
                # "definitionProvider": True,
            },
            "serverInfo": {
                "name":    SERVER_NAME,
                "version": SERVER_VERSION,
            }
        })

    def on_initialized(self, msg: dict):
        # VS Code sends this after the handshake — nothing to do yet
        pass

    def on_shutdown(self, msg: dict):
        self.shutdown_flag = True
        self.send_response(msg["id"], result=None)

    def on_exit(self, msg: dict):
        sys.exit(0)

    # ── Document sync ──────────────────────────────────────────────────────────

    def on_did_open(self, msg: dict):
        td   = msg["params"]["textDocument"]
        uri  = td["uri"]
        text = td["text"]
        self.documents[uri] = text
        self._schedule_diagnostics(uri)

    def on_did_change(self, msg: dict):
        td  = msg["params"]["textDocument"]
        uri = td["uri"]
        # With sync mode 1 (full), contentChanges[0].text is the whole file
        changes = msg["params"].get("contentChanges", [])
        if changes:
            self.documents[uri] = changes[-1]["text"]
        self._schedule_diagnostics(uri)

    def on_did_close(self, msg: dict):
        uri = msg["params"]["textDocument"]["uri"]
        self.documents.pop(uri, None)
        # Clear diagnostics for closed file
        self.send_notification("textDocument/publishDiagnostics", {
            "uri": uri,
            "diagnostics": []
        })

    def on_did_save(self, msg: dict):
        uri = msg["params"]["textDocument"]["uri"]
        # Force immediate re-check on save (cancel debounce)
        self._cancel_debounce(uri)
        self._run_diagnostics(uri)

    # ── Diagnostics ───────────────────────────────────────────────────────────

    def _schedule_diagnostics(self, uri: str):
        """Debounce: wait 400ms after last change before compiling."""
        self._cancel_debounce(uri)
        t = threading.Timer(self._debounce_delay, self._run_diagnostics, args=[uri])
        self._debounce_timers[uri] = t
        t.start()

    def _cancel_debounce(self, uri: str):
        t = self._debounce_timers.pop(uri, None)
        if t:
            t.cancel()

    def _run_diagnostics(self, uri: str):
        text = self.documents.get(uri)
        if text is None:
            return

        # Skip .mchi interface files entirely
        if uri.endswith('.mchi'):
            self.send_notification("textDocument/publishDiagnostics",
                                {"uri": uri, "diagnostics": []})
            return

        # Skip library files: live in lib/ folder and start with mocha-
        from pathlib import PurePosixPath
        path_parts = uri.replace('\\', '/').lower()
        filename = uri.replace('\\', '/').split('/')[-1]
        if '/lib/' in path_parts and filename.startswith('mocha-'):
            self.send_notification("textDocument/publishDiagnostics",
                                {"uri": uri, "diagnostics": []})
            return

        diagnostics = run_mocha_compiler(text, uri)
        self.send_notification("textDocument/publishDiagnostics",
                            {"uri": uri, "diagnostics": diagnostics})

    # ── JSON-RPC send helpers ──────────────────────────────────────────────────

    def send_response(self, msg_id, result=None, error=None):
        msg = {"jsonrpc": "2.0", "id": msg_id}
        if error is not None:
            msg["error"] = error
        else:
            msg["result"] = result
        write_message(sys.stdout.buffer, msg)

    def send_notification(self, method: str, params: dict):
        write_message(sys.stdout.buffer, {
            "jsonrpc": "2.0",
            "method":  method,
            "params":  params
        })


# ── Main loop ──────────────────────────────────────────────────────────────────

def main():
    # Disable Python's own stdout buffering — LSP must flush immediately
    server = MochaLSP()

    log(f"{SERVER_NAME} {SERVER_VERSION} started, waiting for VS Code...")

    while not server.shutdown_flag:
        try:
            msg = read_message(sys.stdin.buffer)
            if msg is None:
                break  # stdin closed
            server.handle(msg)
        except KeyboardInterrupt:
            break
        except Exception as e:
            log(f"Error handling message: {e}")

    log("Server exiting.")


def log(msg: str):
    """Log to stderr (VS Code shows this in Output > Mocha Language Server)."""
    print(f"[mocha-lsp] {msg}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    main()