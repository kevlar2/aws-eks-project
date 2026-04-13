#!/bin/sh
# Validate LOG_LEVEL against allowed values
case "${LOG_LEVEL:-INFO}" in
  DEBUG|INFO|WARN|ERROR|NONE)
    SANITIZED_LOG_LEVEL="${LOG_LEVEL:-INFO}"
    ;;
  *)
    echo "WARNING: Unknown LOG_LEVEL '${LOG_LEVEL}', defaulting to INFO"
    SANITIZED_LOG_LEVEL="INFO"
    ;;
esac

# Generate runtime config from environment variables
echo "window.__CONFIG__ = { LOG_LEVEL: \"${SANITIZED_LOG_LEVEL}\" };" > /app/js/config.js

echo "Starting 2048 with LOG_LEVEL=${SANITIZED_LOG_LEVEL}"

exec python3 /app/server.py
