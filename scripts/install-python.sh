#!/usr/bin/env sh
# Install uv + Python into $HOME (persists with whole-home volume).
# Usage: install-python [version]
# Env:   PYTHON_VERSION (default: 3.15), UV_INSTALL_DIR, HOME

set -eu

PYTHON_VERSION="${1:-${PYTHON_VERSION:-3.15}}"
HOME_DIR="${HOME:-/home/vibecoder}"
UV_INSTALL_DIR="${UV_INSTALL_DIR:-${HOME_DIR}/.local}"
export UV_INSTALL_DIR
export PATH="${UV_INSTALL_DIR}/bin:${HOME_DIR}/.local/bin:${PATH}"

if ! command -v uv >/dev/null 2>&1; then
  echo "Installing uv into ${UV_INSTALL_DIR}"
  curl -fsSL https://astral.sh/uv/install.sh | sh
  export PATH="${UV_INSTALL_DIR}/bin:${HOME_DIR}/.local/bin:${PATH}"
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv not found on PATH after install" >&2
  exit 1
fi

echo "Ensuring Python ${PYTHON_VERSION} via uv"
uv python install "$PYTHON_VERSION"

mkdir -p "${HOME_DIR}/.local/bin"
py_bin="$(uv python find "$PYTHON_VERSION" 2>/dev/null || true)"
if [ -n "$py_bin" ] && [ -x "$py_bin" ]; then
  ln -sfn "$py_bin" "${HOME_DIR}/.local/bin/python3"
  ln -sfn "$py_bin" "${HOME_DIR}/.local/bin/python"
fi

uv --version
python3 --version 2>/dev/null || python --version 2>/dev/null || true
echo "Installed Python ${PYTHON_VERSION} via uv under ${HOME_DIR}"
