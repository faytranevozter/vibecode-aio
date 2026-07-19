#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -gt 0 ]]; then
  exec "$@"
fi

shutdown() {
  trap - TERM INT EXIT
  kill -TERM "${ninerouter_pid:-}" "${openchamber_pid:-}" 2>/dev/null || true
  wait "${ninerouter_pid:-}" "${openchamber_pid:-}" 2>/dev/null || true
}

trap shutdown TERM INT EXIT

node /usr/local/lib/node_modules/9router/app/custom-server.js &
ninerouter_pid=$!

openchamber_args=()
if [[ -n "${OPENCHAMBER_UI_PASSWORD:-}" ]]; then
  openchamber_args+=(--ui-password "$OPENCHAMBER_UI_PASSWORD")
fi
openchamber "${openchamber_args[@]}"
openchamber logs &
openchamber_pid=$!

while kill -0 "$ninerouter_pid" 2>/dev/null && kill -0 "$openchamber_pid" 2>/dev/null; do
  sleep 2
done

wait "$ninerouter_pid" "$openchamber_pid"
