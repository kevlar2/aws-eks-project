#!/bin/sh
# Generate runtime config from environment variables
echo "window.__CONFIG__ = { LOG_LEVEL: \"${LOG_LEVEL:-INFO}\" };" > /app/js/config.js

echo "Starting 2048 with LOG_LEVEL=${LOG_LEVEL:-INFO}"

exec python3 /app/server.py
