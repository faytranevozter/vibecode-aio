#!/usr/bin/env sh
# Install nvm and Node.js into $HOME (persists with whole-home volume).
# Usage: install-node [version]
# Env:   NODE_VERSION (default: --lts), NVM_VERSION, NVM_DIR, HOME

set -eu

NODE_VERSION="${1:-${NODE_VERSION:---lts}}"
NVM_VERSION="${NVM_VERSION:-0.40.6}"
HOME_DIR="${HOME:-/home/vibecoder}"
NVM_DIR="${NVM_DIR:-${HOME_DIR}/.nvm}"
export NVM_DIR

mkdir -p "$NVM_DIR"

if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
  echo "Installing nvm ${NVM_VERSION} into ${NVM_DIR}"
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | PROFILE=/dev/null bash
fi

# shellcheck disable=SC1091
. "${NVM_DIR}/nvm.sh"

case "$NODE_VERSION" in
  lts|lts/*)
    install_spec="--lts"
    ;;
  *)
    install_spec="$NODE_VERSION"
    ;;
esac

echo "Installing Node.js ${NODE_VERSION} with nvm"
nvm install "$install_spec"
nvm use --silent "$install_spec" >/dev/null

resolved="$(node --version)"

nvm alias default "$resolved" >/dev/null
nvm use --silent default >/dev/null

node --version
npm --version
echo "Installed Node.js ${resolved} with nvm at ${NVM_DIR}"
