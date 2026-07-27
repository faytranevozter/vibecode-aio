#!/usr/bin/env sh
# Install Rust via rustup into $HOME (persists with whole-home volume).
# Usage: install-rust [toolchain]
# Env:   RUST_VERSION / toolchain arg (default: stable), CARGO_HOME, RUSTUP_HOME

set -eu

TOOLCHAIN="${1:-${RUST_VERSION:-stable}}"
HOME_DIR="${HOME:-/home/vibecoder}"
CARGO_HOME="${CARGO_HOME:-${HOME_DIR}/.cargo}"
RUSTUP_HOME="${RUSTUP_HOME:-${HOME_DIR}/.rustup}"

export CARGO_HOME RUSTUP_HOME
export PATH="${CARGO_HOME}/bin:${PATH}"

if [ -x "${CARGO_HOME}/bin/rustc" ] && [ -x "${CARGO_HOME}/bin/rustup" ]; then
  if rustup show active-toolchain 2>/dev/null | grep -q "^${TOOLCHAIN}"; then
    echo "Rust toolchain '${TOOLCHAIN}' already installed"
    rustc --version
    cargo --version
    exit 0
  fi
  echo "Installing / switching to toolchain '${TOOLCHAIN}'"
  rustup toolchain install "$TOOLCHAIN"
  rustup default "$TOOLCHAIN"
  rustc --version
  cargo --version
  exit 0
fi

echo "Installing rustup (toolchain=${TOOLCHAIN})"
curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path --default-toolchain "$TOOLCHAIN"

export PATH="${CARGO_HOME}/bin:${PATH}"
rustc --version
cargo --version
echo "Installed Rust to ${CARGO_HOME} (RUSTUP_HOME=${RUSTUP_HOME})"
