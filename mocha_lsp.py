#!/usr/bin/env python3
"""
mocha_lsp.py — Mocha Language Server Protocol server
Speaks JSON-RPC over stdin/stdout.
Start: python mocha_lsp.py
VS Code connects via the extension.
"""

import sys
import json
import threading
import subprocess
import tempfile
import os
from pathlib import Path

from mocha_doc import collect_items, parse_doc_lines

# ── Constants ──────────────────────────────────────────────────────────────────

SERVER_NAME    = "mocha-lsp"
SERVER_VERSION = "0.1.0"

# Path to your Mocha compiler entry point
MOCHA_COMPILER = Path(__file__).parent / "mocha_compile.py"
LIB_DIR = Path(__file__).parent / "lib"

def build_hover_markdown(item: dict) -> str:
    """Build a markdown string for VS Code hover popup."""
    lines = []

    # Signature line
    kind = item.get("kind", "function")
    if kind == "class":
        lines.append(f"```mocha\nclass {item['name']}\n```")
    else:
        params = ", ".join(f"{n}: {t}" for n, t in item.get("params", []))
        ret    = item.get("return_type", "null")
        parent = item.get("parent")
        name   = f"{parent}.{item['name']}" if parent else item["name"]
        lines.append(f"```mocha\nfunction {name}({params}) -> {ret}\n```")

    # Docstring description
    desc, doc_params, doc_return = parse_doc_lines(item.get("doc_desc") or [])
    
    # doc_desc is already parsed by collect_items so use it directly
    if item.get("doc_desc"):
        for desc_line in item["doc_desc"]:
            desc_line = desc_line.strip()
            if desc_line:
                lines.append(f"\n{desc_line}  ")

    # @param entries
    if item.get("doc_params"):
        lines.append("\n**Parameters**")
        for pname, pdesc in item["doc_params"]:
            lines.append(f"- `{pname}` — {pdesc}")

    # @return
    if item.get("doc_return"):
        lines.append(f"\n**Returns** — {item['doc_return']}")

    # No doc at all
    if not item.get("has_doc"):
        lines.append("\n*No documentation.*")

    return "\n".join(lines)

def get_signature_context(source_text: str, line: int, char: int):
    """
    Walk backwards from cursor to find:
    - the function name being called
    - which parameter index the cursor is on (0-based)
    Returns (function_name, param_index) or (None, 0) if not in a call.
    """
    lines = source_text.replace('\r\n', '\n').split('\n')
    if line >= len(lines):
        return None, 0

    # Build a single string of everything up to the cursor
    before = '\n'.join(lines[:line]) + '\n' + lines[line][:char]

    # Walk backwards to find the opening '(' at depth 0
    depth       = 0
    param_index = 0
    i = len(before) - 1

    while i >= 0:
        ch = before[i]
        if ch == ')':
            depth += 1
        elif ch == '(':
            if depth == 0:
                # This is our opening paren — function name is just before it
                name_end = i
                name_start = name_end - 1
                while name_start >= 0 and (before[name_start].isalnum() or before[name_start] == '_'):
                    name_start -= 1
                func_name = before[name_start + 1:name_end]
                return func_name if func_name else None, param_index
            else:
                depth -= 1
        elif ch == ',' and depth == 0:
            param_index += 1
        i -= 1

    return None, 0

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
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

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
        self._symbol_table: dict[str, dict] = {}  # uri -> {name: item}
        self._global_symbols: dict[str, dict] = {}
        self._write_lock = threading.Lock()

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
            "textDocument/hover":            self.on_hover,
            "textDocument/definition":       self.on_definition,
            "textDocument/signatureHelp":    self.on_signature_help,
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
                "hoverProvider": True,
                # We'll add more capabilities here as we build them:
                # "completionProvider": {"triggerCharacters": [".", " "]},
                "definitionProvider": True,
                "signatureHelpProvider": {
                    "triggerCharacters":   ["(", ","],
                    "retriggerCharacters": [","]
                },
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

    def on_hover(self, msg: dict):
        params  = msg["params"]
        uri     = params["textDocument"]["uri"]
        line    = params["position"]["line"]
        char    = params["position"]["character"]
        msg_id  = msg["id"]

        table = self._symbol_table.get(uri, {})

        # Extract word under cursor from source text
        text  = self.documents.get(uri, "")
        lines = text.replace('\r\n', '\n').split('\n')
        if line >= len(lines):
            self.send_response(msg_id, result=None)
            return

        source_line = lines[line]
        # Walk left and right from cursor to find word boundaries
        start = char
        while start > 0 and (source_line[start - 1].isalnum() or source_line[start - 1] == '_'):
            start -= 1
        end = char
        while end < len(source_line) and (source_line[end].isalnum() or source_line[end] == '_'):
            end += 1

        word = source_line[start:end]
        if not word:
            self.send_response(msg_id, result=None)
            return

        item = table.get(word)
        if not item:
            item = self._global_symbols.get(word)
        if not item:
            self.send_response(msg_id, result=None)
            return

        # Build markdown hover content
        hover_md = build_hover_markdown(item)
        self.send_response(msg_id, result={
            "contents": {
                "kind":  "markdown",
                "value": hover_md
            }
        })
    
    def on_definition(self, msg: dict):
        params = msg["params"]
        uri    = params["textDocument"]["uri"]
        line   = params["position"]["line"]
        char   = params["position"]["character"]
        msg_id = msg["id"]

        text  = self.documents.get(uri, "")
        lines = text.replace('\r\n', '\n').split('\n')
        if line >= len(lines):
            self.send_response(msg_id, result=None)
            return

        source_line = lines[line]
        start = char
        while start > 0 and (source_line[start-1].isalnum() or source_line[start-1] == '_'):
            start -= 1
        end = char
        while end < len(source_line) and (source_line[end].isalnum() or source_line[end] == '_'):
            end += 1
        word = source_line[start:end]

        if not word:
            self.send_response(msg_id, result=None)
            return

        item = (self._symbol_table.get(uri) or {}).get(word)
        if not item:
            item = self._global_symbols.get(word)
        if not item or not item.get("_uri"):
            self.send_response(msg_id, result=None)
            return

        target_uri  = item["_uri"]
        target_line = max(0, item["_line"] - 1)
        target_col  = max(0, item["_col"]  - 1)

        self.send_response(msg_id, result={
            "uri":   target_uri,
            "range": make_range(target_line, target_col, target_line, target_col)
        })
    
    def on_signature_help(self, msg: dict):
        params = msg["params"]
        uri    = params["textDocument"]["uri"]
        line   = params["position"]["line"]
        char   = params["position"]["character"]
        msg_id = msg["id"]

        text = self.documents.get(uri, "")
        if not text:
            self.send_response(msg_id, result=None)
            return

        func_name, param_index = get_signature_context(text, line, char)
        if not func_name:
            self.send_response(msg_id, result=None)
            return

        # Look up the function in current file then global symbols
        item = (self._symbol_table.get(uri) or {}).get(func_name)
        if not item:
            item = self._global_symbols.get(func_name)
        if not item:
            self.send_response(msg_id, result=None)
            return

        # Build the full signature label
        params_list = item.get("params", [])
        param_strs  = [f"{n}: {t}" for n, t in params_list]
        full_sig    = f"function {item['name']}({', '.join(param_strs)}) -> {item.get('return_type', 'null')}"

        # Build parameter info for VS Code to highlight active param
        param_infos = []
        for pname, ptype in params_list:
            # Find matching @param doc if exists
            doc_desc = ""
            for dp_name, dp_desc in (item.get("doc_params") or []):
                if dp_name == pname:
                    doc_desc = dp_desc
                    break
            label = f"{pname}: {ptype}"
            param_infos.append({
                "label":         label,
                "documentation": doc_desc if doc_desc else None
            })

        self.send_response(msg_id, result={
            "signatures": [{
                "label":           full_sig,
                "documentation":   {
                    "kind":  "markdown",
                    "value": " ".join(item.get("doc_desc") or [])
                },
                "parameters": param_infos
            }],
            "activeSignature": 0,
            "activeParameter": min(param_index, max(0, len(params_list) - 1))
        })

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

    def _extract_symbols(self, source_text: str, uri: str) -> dict:
        try:
            from mocha_lexer  import Lexer
            from mocha_parser import Parser
            tokens = Lexer(source_text.replace('\r\n', '\n')).tokenise()
            ast    = Parser(tokens).parse(silent=True)
            items  = collect_items(ast)
            table  = {}
            for item in items:
                item["_uri"]  = uri
                item["_line"] = item.get("line", 0)
                item["_col"]  = item.get("col",  0)
                table[item["name"]] = item
                if item.get("kind") == "class":
                    for method in item.get("methods", []):
                        method["_uri"]  = uri
                        method["_line"] = method.get("line", 0)
                        method["_col"]  = method.get("col",  0)
                        table[f"{item['name']}.{method['name']}"] = method
                        table[method["name"]] = method
            return table
        except SystemExit as e:
            log(f"SYSTEM EXIT in _extract_symbols: {e} uri={uri}")
            return {}
        except Exception as e:
            log(f"ERROR in _extract_symbols: {e} uri={uri}")
            return {}
    
    def _index_imports(self, source_text: str):
        try:
            from mocha_lexer  import Lexer
            from mocha_parser import Parser
            from mocha_ast    import ImportStmt
            tokens = Lexer(source_text.replace('\r\n', '\n')).tokenise()
            ast    = Parser(tokens).parse(silent=True)
            for node in ast.statements:
                if not isinstance(node, ImportStmt):
                    continue
                lib_name = node.source
                lib_path = LIB_DIR / f"{lib_name}.mch"
                if not lib_path.exists():
                    continue
                lib_uri = lib_path.as_uri()
                if lib_uri in self._symbol_table:
                    continue
                try:
                    lib_text = lib_path.read_text(encoding='utf-8')
                    table = self._extract_symbols(lib_text, lib_uri)
                    self._symbol_table[lib_uri] = table
                    self._global_symbols.update(table)
                    log(f"Indexed lib: {lib_name} ({len(table)} symbols)")
                except SystemExit as e:
                    log(f"SYSTEM EXIT indexing {lib_name}: {e}")
                except Exception as e:
                    log(f"Failed to index {lib_name}: {e}")
        except Exception:
            pass
    
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

        path_parts = uri.replace('\\', '/').lower()
        filename   = uri.replace('\\', '/').split('/')[-1]
        is_mchi    = uri.endswith('.mchi')
        is_lib     = '/lib/' in path_parts and filename.startswith('mocha-')

        # Build symbol table and index imports
        table = self._extract_symbols(text, uri)
        if table:
            self._symbol_table[uri] = table
            self._global_symbols.update(table)
        self._index_imports(text)

        # Skip diagnostics for lib and interface files
        if is_mchi or is_lib:
            self.send_notification("textDocument/publishDiagnostics",
                                {"uri": uri, "diagnostics": []})
            return

        diagnostics = run_mocha_compiler(text, uri)
        self.send_notification("textDocument/publishDiagnostics",
                            {"uri": uri, "diagnostics": diagnostics})

    # ── JSON-RPC send helpers ──────────────────────────────────────────────────

    def send_response(self, msg_id, result=None, error=None):
        msg = {"jsonrpc": "2.0", "id": msg_id}
        msg["error" if error is not None else "result"] = error if error is not None else result
        with self._write_lock:
            write_message(sys.stdout.buffer, msg)

    def send_notification(self, method: str, params: dict):
        with self._write_lock:
            write_message(sys.stdout.buffer, {
                "jsonrpc": "2.0", "method": method, "params": params
            })


# ── Main loop ──────────────────────────────────────────────────────────────────

# Disable Python's own stdout buffering — LSP must flush immediately
def main():
    server = MochaLSP()
    log(f"{SERVER_NAME} {SERVER_VERSION} started, waiting for VS Code...")

    while not server.shutdown_flag:
        try:
            msg = read_message(sys.stdin.buffer)
            if msg is None:
                break
            server.handle(msg)
        except KeyboardInterrupt:
            break
        except SystemExit as e:
            log(f"SYSTEM EXIT in main loop: {e}")
            break
        except Exception as e:
            import traceback
            log(f"UNHANDLED ERROR in main loop: {e}")
            log(traceback.format_exc())

    log("Exiting.")


def log(msg: str):
    """Log to stderr (VS Code shows this in Output > Mocha Language Server)."""
    print(f"[mocha-lsp] {msg}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    main()