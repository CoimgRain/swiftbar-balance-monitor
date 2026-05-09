#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

exec /usr/bin/python3 "$APP_DIR/{{SERVICE_ID}}/fetch_usage.py" --text
