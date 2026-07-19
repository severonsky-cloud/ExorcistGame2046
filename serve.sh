#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
PORT="${PORT:-8080}"
printf '%s\n' "Open http://localhost:${PORT}/play.html"

if command -v python3 >/dev/null 2>&1; then
  python3 -m http.server "$PORT" --bind 127.0.0.1
elif command -v python >/dev/null 2>&1; then
  python -m http.server "$PORT" --bind 127.0.0.1
elif command -v node >/dev/null 2>&1; then
  PORT="$PORT" node scripts/server.mjs
else
  printf '%s\n' 'Python or Node.js is required.' >&2
  exit 1
fi
