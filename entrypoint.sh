#!/bin/sh
set -eu

: "${API_TOKEN:?missing API_TOKEN}"

CONFIG="${CONFIG:-/config/hcloud-dyndns.conf}"
INTERVAL="${INTERVAL:-300}"
MODE="${MODE:-loop}"              # loop | once
SCRIPT_FLAGS="${SCRIPT_FLAGS:-}"  # e.g. "--verbose" or "--quiet"

if [ ! -f "$CONFIG" ]; then
  echo "[ERR] Config not found: $CONFIG" >&2
  exit 2
fi

run_once() {
  # shellcheck disable=SC2086
  /usr/local/bin/hcloud-dyndns.sh $SCRIPT_FLAGS "$CONFIG"
}

case "$MODE" in
  once)
    run_once
    ;;
  loop)
    while true; do
      run_once || true
      sleep "$INTERVAL"
    done
    ;;
  *)
    echo "[ERR] Invalid MODE: $MODE (use 'loop' or 'once')" >&2
    exit 3
    ;;
esac
