# 2048 Game - AWS EKS Project

A containerized version of the [2048 puzzle game](https://en.wikipedia.org/wiki/2048_(video_game)), built for deployment on AWS EKS.

## Tech Stack

- **Frontend**: Vanilla JavaScript (ES5), HTML, SCSS/CSS
- **Server**: Custom threaded Python HTTP server (`server.py`) for static file serving, log ingestion, and health checks
- **Container**: Docker (multi-stage build, non-root user)
- **Deployment**: AWS EKS (Kubernetes)

## Project Structure

```
app/
├── Dockerfile              # Multi-stage Docker build
├── entrypoint.sh           # Container entrypoint (generates runtime config, starts server)
├── server.py               # Custom Python HTTP server with POST /log endpoint
├── index.html              # Main HTML entry point
├── js/
│   ├── application.js      # App bootstrap
│   ├── game_manager.js     # Core game logic (moves, merges, scoring, win/lose)
│   ├── grid.js             # 4x4 grid data structure
│   ├── tile.js             # Tile data model
│   ├── html_actuator.js    # DOM rendering (tiles, scores, messages)
│   ├── keyboard_input_manager.js  # Keyboard and touch/swipe input handling
│   ├── local_storage_manager.js   # Game state persistence via localStorage
│   ├── logger.js           # Logging utility (browser console + server forwarding)
│   ├── config.js           # Runtime config (generated at container startup)
│   ├── bind_polyfill.js    # Function.prototype.bind polyfill
│   ├── classlist_polyfill.js  # Element.classList polyfill
│   └── animframe_polyfill.js  # requestAnimationFrame polyfill
├── style/
│   ├── main.scss           # Primary SCSS source
│   ├── helpers.scss        # SCSS mixins/helpers
│   ├── main.css            # Compiled CSS
│   └── fonts/              # Clear Sans web font files
├── meta/                   # iOS touch icons and splash screens
├── .jshintrc               # JSHint linting configuration
├── CONTRIBUTING.md          # Contribution guidelines
├── LICENSE.txt             # License
├── Rakefile                # Ruby rake task (legacy)
└── package-lock.json       # npm lockfile (no dependencies)
```

## Run Locally

### Without Docker

Requires Python 3:

```bash
python3 server.py
```

Open http://localhost:3000/

### With Docker

```bash
docker build -t 2048-app .
docker run -p 3000:3000 2048-app
```

Open http://localhost:3000/

> **Note**: If port 3000 is already in use, remap to a different host port:
> ```bash
> docker run -p 8080:3000 2048-app
> ```

## Logging

The app includes a client-side logging system that forwards log events to the container's stdout, making them visible via `docker logs` and `kubectl logs`.

### Log Levels

| Level | Value | Description |
|-------|-------|-------------|
| `DEBUG` | 0 | Verbose: tile spawns, individual moves, merges, key presses, swipes, storage I/O |
| `INFO` | 1 | Standard: game start/restart/restore, win, game over, best score, app lifecycle |
| `WARN` | 2 | Warnings: localStorage fallback |
| `ERROR` | 3 | Errors: localStorage failures, server-side log processing errors |
| `NONE` | 4 | Silent: all logging disabled |

### Configuration

Set the `LOG_LEVEL` environment variable:

```bash
# Docker
docker run -p 3000:3000 -e LOG_LEVEL=DEBUG 2048-app

# Kubernetes deployment manifest
env:
  - name: LOG_LEVEL
    value: "DEBUG"
```

Default is `INFO`. Invalid values are rejected with a warning and fall back to `INFO`. The value is validated against the allowlist (`DEBUG`, `INFO`, `WARN`, `ERROR`, `NONE`) in both `entrypoint.sh` and `server.py`.

### Example Container Output (INFO)

```
Starting 2048 with LOG_LEVEL=INFO
Server running on port 3000
[2026-04-13T12:00:00.000Z] [INFO] [App] 2048 application starting
[2026-04-13T12:00:00.010Z] [INFO] [Storage] Using localStorage for persistence
[2026-04-13T12:00:00.012Z] [INFO] [Game] GameManager initialized with grid size 4x4
[2026-04-13T12:00:00.015Z] [INFO] [Game] New game started
[2026-04-13T12:00:00.020Z] [INFO] [App] 2048 application ready
[2026-04-13T12:00:05.100Z] [INFO] [Game] New best score: 128
[2026-04-13T12:00:30.500Z] [INFO] [Game] Game over! No moves available. Final score: 1284
```

### Runtime Override

Log level can also be changed at runtime via the browser console:

```js
Logger.setLevel("DEBUG");   // verbose
Logger.setLevel("NONE");    // silent
```

## Docker Details

- **Base image**: Python (pinned by SHA digest)
- **Multi-stage build**: build stage copies source, runtime stage includes only required files
- **Non-root user**: runs as `my_user` (UID 1000)
- **Exposed port**: 3000
- **Entrypoint**: `entrypoint.sh` validates `LOG_LEVEL` against an allowlist, generates `js/config.js`, then starts `server.py`
- **Healthcheck**: `GET /health` returns `200 ok` — checked every 30s with 3 retries
- **Threading**: `server.py` uses `ThreadingHTTPServer` so log ingestion doesn't block static file serving

## CI Pipeline

A GitHub Actions workflow (`.github/workflows/build-push-image.yaml`) runs on pushes to `main` and pull requests targeting `main`, filtered to changes in `app/**` or the workflow file itself.

### Pipeline Steps

1. **Build** Docker image, tagged with short commit SHA (7 chars) and `latest`
2. **Trivy image scan** - reports CRITICAL, HIGH, and MEDIUM vulnerabilities
3. **Trivy critical gate** - fails the build if CRITICAL vulnerabilities are found (HIGH/MEDIUM are reported only)
4. **Trivy Dockerfile scan** - checks for misconfigurations in the Dockerfile
5. **Checkov Dockerfile scan** - static analysis for Dockerfile best practices
6. **Summary** - all scan results and image details are written to the GitHub Actions job summary

### ECR Push (Not Yet Active)

ECR authentication and push steps are included but commented out. Uncomment when the ECR repository is set up.

## How to Play

Use **arrow keys**, **WASD**, or **swipe** on mobile to move tiles. When two tiles with the same number touch, they merge into one. Reach the **2048 tile** to win.
