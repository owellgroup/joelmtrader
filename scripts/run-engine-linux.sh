#!/usr/bin/env bash
# Run the engine locally on Linux/macOS in PAPER mode (simulator) - handy for development.
set -e
cd "$(dirname "$0")/../engine"
set -a; [ -f ../.env ] && . ../.env; set +a
export JAVA_EVENTS_URL=${JAVA_EVENTS_URL_LOCAL:-http://localhost:8080/internal/events}
export DATA_DIR=./data
python3 -m venv .venv 2>/dev/null || true
. .venv/bin/activate
pip install -q -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
