#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
workspace="${VIBECODE_WORKSPACE:-$PWD}"
env_file="${VIBECODE_ENV_FILE:-$script_dir/../.env}"
docker_socket="${VIBECODE_DOCKER_SOCKET:-/var/run/docker.sock}"
image="${VIBECODE_IMAGE:-ghcr.io/faytranevozter/vibecode-aio:debian}"

fail() {
  printf 'vibecode Docker launcher: %s\n' "$1" >&2
  exit 1
}

[ -d "$workspace" ] || fail "workspace is not a directory: $workspace"
workspace="$(CDPATH= cd -- "$workspace" && pwd -P)"

[ -f "$env_file" ] || fail "environment file not found: $env_file (set VIBECODE_ENV_FILE to override)"
[ -r "$env_file" ] || fail "environment file is not readable: $env_file"
env_file="$(CDPATH= cd -- "$(dirname -- "$env_file")" && pwd -P)/$(basename -- "$env_file")"
[ -e "$docker_socket" ] || fail "Docker socket not found: $docker_socket (start Docker or set VIBECODE_DOCKER_SOCKET)"
[ -S "$docker_socket" ] || fail "Docker socket path is not a Unix socket: $docker_socket"
command -v docker >/dev/null 2>&1 || fail "docker command not found on the host"
docker -H "unix://$docker_socket" info >/dev/null 2>&1 ||
  fail "cannot connect to Docker through: $docker_socket (check that Docker is running and your user can access the socket)"

set -- docker -H "unix://$docker_socket" run --rm --name vibecode-aio \
  --env-file "$env_file"

case "$(uname -s)" in
  Linux)
    socket_gid="${VIBECODE_DOCKER_GID:-}"
    if [ -z "$socket_gid" ]; then
      socket_gid="$(stat -c '%g' "$docker_socket")" ||
        fail "cannot determine Docker socket group; set VIBECODE_DOCKER_GID"
    fi
    case "$socket_gid" in
      ''|*[!0-9]*) fail "Docker socket group must be a numeric GID: $socket_gid" ;;
    esac
    set -- "$@" --group-add "$socket_gid"
    ;;
  Darwin)
    # Docker Desktop and OrbStack expose the mounted socket as root-owned in the VM.
    set -- "$@" --group-add 0
    ;;
  *)
    fail "unsupported host platform: $(uname -s) (use Linux, WSL2, or macOS)"
    ;;
esac

set -- "$@" \
  --mount "type=bind,\"src=$docker_socket\",dst=/var/run/docker.sock" \
  --mount "type=bind,\"src=$workspace\",\"dst=$workspace\"" \
  --workdir "$workspace" \
  -p 3000:3000 \
  -p 20128:20128 \
  -v vibecode-home:/home/vibecoder \
  "$image"

exec "$@"
