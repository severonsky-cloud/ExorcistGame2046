#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
printf '%s\n' 'Open http://localhost:8080 in your browser.'
python3 -m http.server 8080
