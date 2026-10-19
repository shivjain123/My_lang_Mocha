"""mocha_serve.py - tiny local web server for Mocha wasm pages.
   mocha serve                  serve the current folder
   mocha serve page.html        serve that page's folder and open the page
   mocha serve <folder> [port]  serve a folder (default port 8000)"""
import functools, http.server, os, sys, webbrowser

def main():
    target = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
    if os.path.isfile(target):
        folder, page = os.path.dirname(target), os.path.basename(target)
    elif os.path.isdir(target):
        folder, page = target, ""
    else:
        print(f"  ❌ Not found: {target}")
        sys.exit(1)

    class Handler(http.server.SimpleHTTPRequestHandler):
        # Windows can map .js to text/plain, which breaks module scripts, so pin the types we need
        extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                          ".js": "text/javascript", ".mjs": "text/javascript", ".wasm": "application/wasm"}
        def log_message(self, *args):
            pass
        def end_headers(self):
            self.send_header("Cache-Control", "no-cache")   # a rebuild shows up on a plain refresh
            super().end_headers()

    handler = functools.partial(Handler, directory=folder)
    server = None
    for p in range(port, port + 20):                         # port busy? try the next one
        try:
            server = http.server.ThreadingHTTPServer(("127.0.0.1", p), handler)
            break
        except OSError:
            continue
    if server is None:
        print("  ❌ No free port found")
        sys.exit(1)

    url = f"http://localhost:{server.server_address[1]}/{page}"
    print(f"  🌐 Serving {folder}")
    print(f"     {url}")
    print("     Press Ctrl+C to stop.")
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n  👋 Stopped.")
    finally:
        server.server_close()

if __name__ == "__main__":
    main()