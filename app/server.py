"""
Custom HTTP server for the 2048 game.

- Serves static files from the working directory (same as python3 -m http.server)
- Adds a POST /log endpoint that prints client-side log messages to stdout
- Respects the LOG_LEVEL environment variable to filter which logs reach stdout
"""

import json
import os
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

LOG_LEVELS = {
    "DEBUG": 0,
    "INFO": 1,
    "WARN": 2,
    "ERROR": 3,
    "NONE": 4,
}

SERVER_LOG_LEVEL = LOG_LEVELS.get(os.environ.get("LOG_LEVEL", "INFO"), 1)


class GameRequestHandler(SimpleHTTPRequestHandler):
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
        # Suppress default access logs for POST /log to avoid noise
        if len(args) >= 1 and "POST /log" in str(args[0]):
            return
        super().log_message(format, *args)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 3000))
    server = HTTPServer(("0.0.0.0", port), GameRequestHandler)
    print("Server running on port {}".format(port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.", flush=True)
        server.server_close()
