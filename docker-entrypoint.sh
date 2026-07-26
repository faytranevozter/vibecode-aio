#!/bin/sh
set -eu

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

mkdir -p "${OPENCODE_CONFIG_DIR:-/home/vibecoder/.config/opencode}"

seed_opencode_config() {
  config_dir="${OPENCODE_CONFIG_DIR:-/home/vibecoder/.config/opencode}"
  config_file="$config_dir/opencode.json"

  if [ ! -f "$config_file" ]; then
    cp /usr/local/share/vibecode/opencode.default.json "$config_file"
    return
  fi

  node - "$config_file" <<'EOF'
const fs = require('fs');

const file = process.argv[2];
const config = JSON.parse(fs.readFileSync(file, 'utf8'));
config.$schema = config.$schema || 'https://opencode.ai/config.json';
config.mcp = config.mcp || {};

config.mcp.context7 = {
  type: 'local',
  command: ['sh', '-c', 'exec context7-mcp --api-key "$CONTEXT7_API_KEY"'],
  enabled: true,
  timeout: 30000,
};

config.mcp['codegraph'] = {
  type: 'local',
  command: ['codegraph', 'serve', '--mcp'],
  enabled: true,
  timeout: 30000,
};

if (!config.permission) config.permission = {};
if (!config.permission.bash) config.permission.bash = { '*': 'ask' };
if (!config.permission.bash['gh *']) config.permission.bash['gh *'] = 'ask';

fs.writeFileSync(file, JSON.stringify(config, null, 2) + '\n');
EOF
}

seed_opencode_config

init_rtk_opencode() {
  case "${RTK_OPENCODE_INIT:-1}" in
    0|false|no)
      return
      ;;
  esac

  if ! rtk init -g --opencode --auto-patch; then
    echo "warning: rtk OpenCode auto-init failed; continuing startup" >&2
  fi
}

init_rtk_opencode

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
