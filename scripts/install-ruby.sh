#!/usr/bin/env sh
# Install rbenv + Ruby into $HOME (persists with whole-home volume).
# Usage: install-ruby [version]
# Env:   RUBY_VERSION (default: 4.0.6), RBENV_ROOT, HOME
# Note: compiling Ruby needs build deps on the image (gcc, make, openssl headers).
#       Prefer the debian tag. If compile fails, install OS build packages first.

set -eu

RUBY_VERSION="${1:-${RUBY_VERSION:-4.0.6}}"
HOME_DIR="${HOME:-/home/vibecoder}"
RBENV_ROOT="${RBENV_ROOT:-${HOME_DIR}/.rbenv}"
export RBENV_ROOT
export PATH="${RBENV_ROOT}/bin:${RBENV_ROOT}/shims:${PATH}"

if [ ! -d "${RBENV_ROOT}/.git" ] && [ ! -x "${RBENV_ROOT}/bin/rbenv" ]; then
  echo "Installing rbenv into ${RBENV_ROOT}"
  git clone --depth 1 https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
  mkdir -p "${RBENV_ROOT}/plugins"
  git clone --depth 1 https://github.com/rbenv/ruby-build.git \
    "${RBENV_ROOT}/plugins/ruby-build"
fi

if [ ! -d "${RBENV_ROOT}/plugins/ruby-build/.git" ] && [ ! -d "${RBENV_ROOT}/plugins/ruby-build" ]; then
  mkdir -p "${RBENV_ROOT}/plugins"
  git clone --depth 1 https://github.com/rbenv/ruby-build.git \
    "${RBENV_ROOT}/plugins/ruby-build"
fi

# Optional: keep ruby-build current when already present
if [ -d "${RBENV_ROOT}/plugins/ruby-build/.git" ]; then
  git -C "${RBENV_ROOT}/plugins/ruby-build" pull --ff-only 2>/dev/null || true
fi

export PATH="${RBENV_ROOT}/bin:${RBENV_ROOT}/shims:${PATH}"
eval "$(rbenv init - sh)" 2>/dev/null || true

if rbenv versions --bare 2>/dev/null | grep -qx "$RUBY_VERSION"; then
  echo "Ruby ${RUBY_VERSION} already installed"
  rbenv global "$RUBY_VERSION"
  ruby --version
  gem --version
  exit 0
fi

echo "Installing Ruby ${RUBY_VERSION} (may take several minutes)"
if ! rbenv install -s "$RUBY_VERSION"; then
  echo "error: rbenv install failed. On debian, try as root once:" >&2
  echo "  apt-get update && apt-get install -y build-essential libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev" >&2
  exit 1
fi

rbenv global "$RUBY_VERSION"
rbenv rehash
ruby --version
gem --version
echo "Installed Ruby ${RUBY_VERSION} via rbenv at ${RBENV_ROOT}"
