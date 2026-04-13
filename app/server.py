"""
Custom HTTP server for the 2048 game.

- Serves static files from the working directory (same as python3 -m http.server)
- Adds a POST /log endpoint that prints client-side log messages to stdout
- Respects the LOG_LEVEL environment variable to filter which logs reach stdout
"""

import json
import os
import sys
from http.server import SimpleHTTPRequestHandler
from socketserver import ThreadingMixIn
from http.server import HTTPServer

LOG_LEVELS = {
    "DEBUG": 0,
    "INFO": 1,
    "WARN": 2,
    "ERROR": 3,
    "NONE": 4,
}

def _get_server_log_level():
    raw_log_level = os.environ.get("LOG_LEVEL", "INFO")
    normalized_log_level = raw_log_level.strip().upper()

    if normalized_log_level in LOG_LEVELS:
        return LOG_LEVELS[normalized_log_level]

    print(
        "[WARN] [Server] Unknown LOG_LEVEL '{}'; defaulting to INFO.".format(raw_log_level),
        file=sys.stderr,
        flush=True,
    )
    return LOG_LEVELS["INFO"]


SERVER_LOG_LEVEL = _get_server_log_level()


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


class GameRequestHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"ok")
            return
        super().do_GET()

    def do_POST(self):
        if self.path == "/log":
            self._handle_log()
        else:
            self.send_error(404, "Not Found")

    def _handle_log(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            payload = json.loads(body)

            level_name = payload.get("level", "INFO")
            category = payload.get("category", "Unknown")
            message = payload.get("message", "")
            timestamp = payload.get("timestamp", "")

            level_value = LOG_LEVELS.get(level_name, 1)

            if level_value >= SERVER_LOG_LEVEL:
                log_line = "[{}] [{}] [{}] {}".format(
                    timestamp, level_name, category, message
                )
                print(log_line, flush=True)

            self.send_response(204)
            self.end_headers()

        except Exception as e:
            print("[ERROR] [Server] Failed to process log: {}".format(e), file=sys.stderr, flush=True)
            self.send_response(400)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress default access logs for healthcheck and POST /log to avoid noise
        if len(args) >= 1:
            request_line = str(args[0])
            if "POST /log" in request_line or "GET /health" in request_line:
                return
        super().log_message(format, *args)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 3000))
    server = ThreadingHTTPServer(("0.0.0.0", port), GameRequestHandler)
    print("Server running on port {}".format(port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.", flush=True)
        server.server_close()
