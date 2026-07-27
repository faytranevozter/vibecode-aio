#!/usr/bin/env sh
# Install Deno into $HOME (persists with whole-home volume).
# Usage: install-deno [version]
# Env:   DENO_VERSION (default: 2.9.4), DENO_INSTALL, HOME

set -eu

DENO_VERSION="${1:-${DENO_VERSION:-2.9.4}}"
HOME_DIR="${HOME:-/home/vibecoder}"
DENO_INSTALL="${DENO_INSTALL:-${HOME_DIR}/.deno}"
export DENO_INSTALL
export PATH="${DENO_INSTALL}/bin:${PATH}"

current=""
if command -v deno >/dev/null 2>&1; then
  current="$(deno --version | awk '/^deno / { print $2 }')"
fi

if [ "$current" = "$DENO_VERSION" ]; then
  echo "Deno ${DENO_VERSION} already installed at ${DENO_INSTALL}"
  deno --version
  exit 0
fi

echo "Installing Deno ${DENO_VERSION} into ${DENO_INSTALL}"
mkdir -p "$DENO_INSTALL"
curl -fsSL https://deno.land/install.sh | sh -s "v${DENO_VERSION}"

export PATH="${DENO_INSTALL}/bin:${PATH}"
deno --version
echo "Installed Deno ${DENO_VERSION} to ${DENO_INSTALL}"
