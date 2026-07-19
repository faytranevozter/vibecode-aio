#!/bin/sh
set -eu

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

ninerouter_pid=""
openchamber_pid=""

shutdown() {
  trap - TERM INT EXIT
  if [ -n "$ninerouter_pid" ]; then kill -TERM "$ninerouter_pid" 2>/dev/null || true; fi
  if [ -n "$openchamber_pid" ]; then kill -TERM "$openchamber_pid" 2>/dev/null || true; fi
  if [ -n "$ninerouter_pid" ]; then wait "$ninerouter_pid" 2>/dev/null || true; fi
  if [ -n "$openchamber_pid" ]; then wait "$openchamber_pid" 2>/dev/null || true; fi
}

trap shutdown TERM INT EXIT

node /usr/local/lib/node_modules/9router/app/custom-server.js &
ninerouter_pid=$!

if [ -n "${OPENCHAMBER_UI_PASSWORD:-}" ]; then
  openchamber --ui-password "$OPENCHAMBER_UI_PASSWORD"
else
  openchamber
fi
openchamber logs &
openchamber_pid=$!

while kill -0 "$ninerouter_pid" 2>/dev/null && kill -0 "$openchamber_pid" 2>/dev/null; do
  sleep 2
done

wait "$ninerouter_pid" "$openchamber_pid" 2>/dev/null || true
