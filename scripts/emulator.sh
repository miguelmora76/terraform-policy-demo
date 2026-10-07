#!/usr/bin/env bash
# Start/stop the local S3 emulator (moto) used for Terraform remote state and the demo resources.
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${EMULATOR_PORT:-5100}"
PIDFILE=".emulator/moto.pid"

case "${1:-}" in
  start)
    mkdir -p .emulator
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then echo "emulator already running"; exit 0; fi
    uv run moto_server -H 127.0.0.1 -p "$PORT" >.emulator/moto.log 2>&1 &
    echo $! >"$PIDFILE"
    for _ in $(seq 1 50); do
      curl -fs "http://127.0.0.1:$PORT/moto-api/" >/dev/null 2>&1 && break
      sleep 0.2
    done
    curl -fs "http://127.0.0.1:$PORT/moto-api/" >/dev/null || { echo "emulator did not start; see .emulator/moto.log" >&2; exit 1; }
    # The remote-state bucket (the emulator needs no credentials).
    curl -fs -X PUT "http://127.0.0.1:$PORT/tf-state" >/dev/null
    echo "emulator up on :$PORT, state bucket tf-state created"
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then kill "$(cat "$PIDFILE")" 2>/dev/null || true; rm -f "$PIDFILE"; fi
    echo "emulator stopped (its in-memory state is gone)"
    ;;
  *) echo "usage: $0 start|stop" >&2; exit 2 ;;
esac
