#!/usr/bin/env sh
# Smoke test the RTK install recipe used by the Dockerfile alpine stage.
# Runs inside the Alpine base image (see .github/workflows/ci.yml) and
# exercises rtk beyond --version: init (OpenCode auto-patch) and gain.
set -eu

: "${RTK_VERSION:?RTK_VERSION is required}"

apk add --no-cache ca-certificates curl gcompat

case "$(uname -m)" in
  x86_64|amd64) RTK_TARGET=x86_64-unknown-linux-musl ;;
  aarch64|arm64) RTK_TARGET=aarch64-unknown-linux-gnu ;;
  *) echo "unsupported RTK architecture: $(uname -m)" >&2; exit 1 ;;
esac

RTK_BASE="https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}"
workdir="$(mktemp -d)"
cd "$workdir"

curl -fsSL "${RTK_BASE}/rtk-${RTK_TARGET}.tar.gz" -o "rtk-${RTK_TARGET}.tar.gz"
curl -fsSL "${RTK_BASE}/checksums.txt" -o checksums.txt
grep "[[:space:]]rtk-${RTK_TARGET}\.tar\.gz\$" checksums.txt | sha256sum -c -
tar -xzf "rtk-${RTK_TARGET}.tar.gz"
install -m 0755 rtk /usr/local/bin/rtk

rtk --version
rtk init -g --opencode --auto-patch
rtk gain
