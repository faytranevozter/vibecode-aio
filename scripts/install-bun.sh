#!/usr/bin/env sh
# Install Bun into $HOME (persists with whole-home volume).
# Usage: install-bun [version]
# Env:   BUN_TOOLCHAIN_VERSION (default: 1.3.14), BUN_INSTALL, HOME

set -eu

BUN_TOOLCHAIN_VERSION="${1:-${BUN_TOOLCHAIN_VERSION:-1.3.14}}"
HOME_DIR="${HOME:-/home/vibecoder}"
BUN_INSTALL="${BUN_INSTALL:-${HOME_DIR}/.bun}"
export BUN_INSTALL
export PATH="${BUN_INSTALL}/bin:${PATH}"

current=""
if [ -x "${BUN_INSTALL}/bin/bun" ]; then
  current="$(${BUN_INSTALL}/bin/bun --version 2>/dev/null || true)"
fi

if [ "$current" = "$BUN_TOOLCHAIN_VERSION" ]; then
  echo "Bun ${BUN_TOOLCHAIN_VERSION} already installed at ${BUN_INSTALL}"
  bun --version
  exit 0
fi

echo "Installing Bun ${BUN_TOOLCHAIN_VERSION} into ${BUN_INSTALL}"
mkdir -p "$BUN_INSTALL"
curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_TOOLCHAIN_VERSION}"

export PATH="${BUN_INSTALL}/bin:${PATH}"
bun --version
echo "Installed Bun ${BUN_TOOLCHAIN_VERSION} to ${BUN_INSTALL}"
