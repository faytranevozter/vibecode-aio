#!/usr/bin/env sh
# Install official Go toolchain into $HOME (persists with whole-home volume).
# Usage: install-go [version]
# Env:   GO_VERSION (default: 1.26.5), HOME, GOROOT, GOPATH

set -eu

GO_VERSION="${1:-${GO_VERSION:-1.26.5}}"
HOME_DIR="${HOME:-/home/vibecoder}"
GOROOT="${GOROOT:-${HOME_DIR}/sdk/go}"
GOPATH="${GOPATH:-${HOME_DIR}/go}"
SDK_PARENT="$(dirname "$GOROOT")"
TMP_DIR="${TMPDIR:-/tmp}/install-go.$$"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

case "$(uname -m)" in
  x86_64|amd64) GO_ARCH=amd64 ;;
  aarch64|arm64) GO_ARCH=arm64 ;;
  *)
    echo "unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

if command -v go >/dev/null 2>&1; then
  current="$(go env GOVERSION 2>/dev/null || go version | awk '{ print $3 }')"
  current="${current#go}"
  if [ "$current" = "$GO_VERSION" ] && [ -x "${GOROOT}/bin/go" ]; then
    echo "Go ${GO_VERSION} already installed at ${GOROOT}"
    go version
    exit 0
  fi
fi

mkdir -p "$SDK_PARENT" "$GOPATH" "$TMP_DIR"
url="https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
echo "Downloading ${url}"
curl -fsSL "$url" -o "$TMP_DIR/go.tar.gz"
rm -rf "$GOROOT"
tar -C "$SDK_PARENT" -xzf "$TMP_DIR/go.tar.gz"
# tarball extracts as $SDK_PARENT/go; rename if GOROOT is not .../go
if [ "$(basename "$GOROOT")" != "go" ]; then
  rm -rf "$GOROOT"
  mv "${SDK_PARENT}/go" "$GOROOT"
fi

export GOROOT GOPATH
export PATH="${GOROOT}/bin:${GOPATH}/bin:${PATH}"
go version
echo "Installed Go ${GO_VERSION} to ${GOROOT} (GOPATH=${GOPATH})"
