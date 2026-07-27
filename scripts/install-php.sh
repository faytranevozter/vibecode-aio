#!/usr/bin/env sh
# Install PHP via phpenv/php-build into $HOME (persists with whole-home volume).
# Usage: install-php [version]
# Env:   PHP_VERSION (default: 8.5.8), PHPENV_ROOT, HOME
# Note: compiling PHP needs build deps on the image. Prefer the debian tag.

set -eu

PHP_VERSION="${1:-${PHP_VERSION:-8.5.8}}"
HOME_DIR="${HOME:-/home/vibecoder}"
PHPENV_ROOT="${PHPENV_ROOT:-${HOME_DIR}/.phpenv}"
export PHPENV_ROOT
export PATH="${PHPENV_ROOT}/bin:${PHPENV_ROOT}/shims:${PATH}"

if [ ! -d "${PHPENV_ROOT}/.git" ] && [ ! -x "${PHPENV_ROOT}/bin/phpenv" ]; then
  echo "Installing phpenv into ${PHPENV_ROOT}"
  git clone --depth 1 https://github.com/phpenv/phpenv.git "$PHPENV_ROOT"
fi

mkdir -p "${PHPENV_ROOT}/plugins"
if [ ! -d "${PHPENV_ROOT}/plugins/php-build" ]; then
  git clone --depth 1 https://github.com/php-build/php-build.git \
    "${PHPENV_ROOT}/plugins/php-build"
fi

if [ -d "${PHPENV_ROOT}/plugins/php-build/.git" ]; then
  git -C "${PHPENV_ROOT}/plugins/php-build" pull --ff-only 2>/dev/null || true
fi

export PATH="${PHPENV_ROOT}/bin:${PHPENV_ROOT}/shims:${PATH}"
eval "$(phpenv init -)" 2>/dev/null || true

if phpenv versions --bare 2>/dev/null | grep -qx "$PHP_VERSION"; then
  echo "PHP ${PHP_VERSION} already installed"
  phpenv global "$PHP_VERSION"
  php --version
  exit 0
fi

echo "Installing PHP ${PHP_VERSION} (may take several minutes)"
if ! phpenv install "$PHP_VERSION"; then
  echo "error: phpenv install failed. On debian, try as root once:" >&2
  echo "  apt-get update && apt-get install -y build-essential autoconf bison re2c pkg-config libssl-dev libcurl4-openssl-dev libxml2-dev libsqlite3-dev libonig-dev libzip-dev zlib1g-dev" >&2
  exit 1
fi

phpenv global "$PHP_VERSION"
php --version
echo "Installed PHP ${PHP_VERSION} via phpenv at ${PHPENV_ROOT}"
