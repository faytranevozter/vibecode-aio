#!/bin/sh
set -eu

HOME_DIR="${HOME:-/home/vibecoder}"
mkdir -p \
  "${HOME_DIR}/.config/openchamber" \
  "${OPENCODE_CONFIG_DIR:-${HOME_DIR}/.config/opencode}" \
  "${HOME_DIR}/.local/share/opencode" \
  "${HOME_DIR}/.local/state/opencode" \
  "${HOME_DIR}/.local/share/9router" \
  "${HOME_DIR}/.local/bin" \
  "${HOME_DIR}/.nvm" \
  "${HOME_DIR}/.deno" \
  "${HOME_DIR}/.bun" \
  "${HOME_DIR}/.phpenv" \
  "${HOME_DIR}/workspaces" \
  "${HOME_DIR}/sdk" \
  "${HOME_DIR}/go"

env_truthy() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

# Comma/space-separated list, e.g. INSTALL_TOOLCHAINS=node,go,rust,python,ruby,deno,bun,php
# Legacy INSTALL_GO=1 / INSTALL_RUST=1 etc. still append to the list.
toolchain_list() {
  list="${INSTALL_TOOLCHAINS:-}"
  if env_truthy "${INSTALL_NODE:-0}"; then
    list="${list:+$list,}node"
  fi
  if env_truthy "${INSTALL_GO:-0}"; then
    list="${list:+$list,}go"
  fi
  if env_truthy "${INSTALL_RUST:-0}"; then
    list="${list:+$list,}rust"
  fi
  if env_truthy "${INSTALL_PYTHON:-0}"; then
    list="${list:+$list,}python"
  fi
  if env_truthy "${INSTALL_RUBY:-0}"; then
    list="${list:+$list,}ruby"
  fi
  if env_truthy "${INSTALL_DENO:-0}"; then
    list="${list:+$list,}deno"
  fi
  if env_truthy "${INSTALL_BUN:-0}"; then
    list="${list:+$list,}bun"
  fi
  if env_truthy "${INSTALL_PHP:-0}"; then
    list="${list:+$list,}php"
  fi
  printf '%s' "$list" | tr '[:upper:]' '[:lower:]' | tr ',;' '  '
}

run_toolchain_install() {
  name="$1"
  status=0
  case "$name" in
    ''|skip|none|false|0) return 0 ;;
    node|nodejs|nvm)
      echo "toolchain: ensuring Node.js ${NODE_VERSION:-default} with nvm under \$HOME"
      if [ -n "${NODE_VERSION:-}" ]; then
        install-node "$NODE_VERSION" || status=$?
      else
        install-node || status=$?
      fi
      ;;
    go|golang)
      echo "toolchain: ensuring Go ${GO_VERSION:-default} under \$HOME"
      if [ -n "${GO_VERSION:-}" ]; then
        install-go "$GO_VERSION" || status=$?
      else
        install-go || status=$?
      fi
      ;;
    rust|rustup|cargo)
      echo "toolchain: ensuring Rust ${RUST_VERSION:-stable} under \$HOME"
      if [ -n "${RUST_VERSION:-}" ]; then
        install-rust "$RUST_VERSION" || status=$?
      else
        install-rust || status=$?
      fi
      ;;
    python|py|uv)
      echo "toolchain: ensuring Python ${PYTHON_VERSION:-default} under \$HOME"
      if [ -n "${PYTHON_VERSION:-}" ]; then
        install-python "$PYTHON_VERSION" || status=$?
      else
        install-python || status=$?
      fi
      ;;
    ruby|rb|rbenv)
      echo "toolchain: ensuring Ruby ${RUBY_VERSION:-default} under \$HOME"
      if [ -n "${RUBY_VERSION:-}" ]; then
        install-ruby "$RUBY_VERSION" || status=$?
      else
        install-ruby || status=$?
      fi
      ;;
    deno)
      echo "toolchain: ensuring Deno ${DENO_VERSION:-default} under \$HOME"
      if [ -n "${DENO_VERSION:-}" ]; then
        install-deno "$DENO_VERSION" || status=$?
      else
        install-deno || status=$?
      fi
      ;;
    bun)
      echo "toolchain: ensuring Bun ${BUN_TOOLCHAIN_VERSION:-default} under \$HOME"
      if [ -n "${BUN_TOOLCHAIN_VERSION:-}" ]; then
        install-bun "$BUN_TOOLCHAIN_VERSION" || status=$?
      else
        install-bun || status=$?
      fi
      ;;
    php|composer)
      echo "toolchain: ensuring PHP ${PHP_VERSION:-default} under \$HOME"
      if [ -n "${PHP_VERSION:-}" ]; then
        install-php "$PHP_VERSION" || status=$?
      else
        install-php || status=$?
      fi
      ;;
    *)
      echo "warning: unknown toolchain '${name}' (supported: node, go, rust, python, ruby, deno, bun, php)" >&2
      return 0
      ;;
  esac
  if [ "$status" -ne 0 ]; then
    echo "warning: install for '${name}' failed; continuing startup" >&2
  fi
  return 0
}

bootstrap_toolchains() {
  tools="$(toolchain_list)"
  if [ -z "$(printf '%s' "$tools" | tr -d '[:space:]')" ]; then
    return 0
  fi
  echo "INSTALL_TOOLCHAINS active: ${tools}"
  for name in $tools; do
    run_toolchain_install "$name"
  done
}

bootstrap_toolchains

activate_nvm_node() {
  nvm_dir="${NVM_DIR:-${HOME_DIR}/.nvm}"
  if [ ! -s "${nvm_dir}/nvm.sh" ]; then
    return 0
  fi

  # shellcheck disable=SC1091
  . "${nvm_dir}/nvm.sh"
  if nvm use --silent default >/dev/null 2>&1; then
    resolved="$(node --version)"
    rm -f "${nvm_dir}/current"
    ln -s "${nvm_dir}/versions/node/${resolved}" "${nvm_dir}/current"
    export PATH="${nvm_dir}/current/bin:${PATH}"
    return 0
  fi

  echo "warning: nvm is installed but no default Node.js version is active; using image fallback" >&2
}

activate_nvm_node

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

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
if (!config.permission.bash['docker *']) config.permission.bash['docker *'] = 'ask';

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

  if ! command -v rtk >/dev/null 2>&1; then
    echo "warning: rtk not available; skipping OpenCode auto-init" >&2
    return
  fi

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
