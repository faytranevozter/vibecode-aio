#!/usr/bin/env sh
# Compare Dockerfile package ARGs against npm latest.
# Exit 0 always; prints KEY=value lines for CI.
# With --write, updates Dockerfile ARGs when newer versions exist and prints CHANGED=1|0.

set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
dockerfile="$root/Dockerfile"
write=0
if [ "${1:-}" = "--write" ]; then
  write=1
fi

get_arg() {
  # ARG NAME=value
  sed -n "s/^ARG ${1}=//p" "$dockerfile" | head -n1
}

npm_latest() {
  npm view "$1" version --userconfig /dev/null 2>/dev/null
}

ninerouter_current="$(get_arg NINEROUTER_VERSION)"
opencode_current="$(get_arg OPENCODE_VERSION)"
openchamber_current="$(get_arg OPENCHAMBER_VERSION)"

ninerouter_latest="$(npm_latest 9router)"
opencode_latest="$(npm_latest opencode-ai)"
openchamber_latest="$(npm_latest @openchamber/web)"

if [ -z "$ninerouter_latest" ] || [ -z "$opencode_latest" ] || [ -z "$openchamber_latest" ]; then
  echo "error: failed to fetch one or more npm package versions" >&2
  echo "9router current=${ninerouter_current} latest=${ninerouter_latest:-missing}" >&2
  echo "opencode-ai current=${opencode_current} latest=${opencode_latest:-missing}" >&2
  echo "@openchamber/web current=${openchamber_current} latest=${openchamber_latest:-missing}" >&2
  exit 1
fi

echo "NINEROUTER_CURRENT=${ninerouter_current}"
echo "NINEROUTER_LATEST=${ninerouter_latest}"
echo "OPENCODE_CURRENT=${opencode_current}"
echo "OPENCODE_LATEST=${opencode_latest}"
echo "OPENCHAMBER_CURRENT=${openchamber_current}"
echo "OPENCHAMBER_LATEST=${openchamber_latest}"

changed=0
if [ "$ninerouter_current" != "$ninerouter_latest" ] \
  || [ "$opencode_current" != "$opencode_latest" ] \
  || [ "$openchamber_current" != "$openchamber_latest" ]; then
  changed=1
fi
echo "CHANGED=${changed}"

if [ "$write" -eq 1 ] && [ "$changed" -eq 1 ]; then
  tmp="$(mktemp)"
  sed \
    -e "s/^ARG NINEROUTER_VERSION=.*/ARG NINEROUTER_VERSION=${ninerouter_latest}/" \
    -e "s/^ARG OPENCODE_VERSION=.*/ARG OPENCODE_VERSION=${opencode_latest}/" \
    -e "s/^ARG OPENCHAMBER_VERSION=.*/ARG OPENCHAMBER_VERSION=${openchamber_latest}/" \
    "$dockerfile" >"$tmp"
  mv "$tmp" "$dockerfile"
  echo "UPDATED_DOCKERFILE=1"
fi
