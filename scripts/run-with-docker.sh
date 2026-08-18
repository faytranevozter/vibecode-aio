#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
workspace="${VIBECODE_WORKSPACE:-$PWD}"
env_file="${VIBECODE_ENV_FILE:-$script_dir/../.env}"
docker_socket="${VIBECODE_DOCKER_SOCKET:-/var/run/docker.sock}"
docker_host="${DOCKER_HOST:-}"
image="${VIBECODE_IMAGE:-ghcr.io/faytranevozter/vibecode-aio:debian}"

case "$docker_host" in
  unix://*)
    if [ "${VIBECODE_DOCKER_SOCKET+x}" != x ]; then
      docker_socket="${docker_host#unix://}"
    fi
    docker_host=""
    ;;
esac

fail() {
  printf 'vibecode Docker launcher: %s\n' "$1" >&2
  exit 1
}

[ -d "$workspace" ] || fail "workspace is not a directory: $workspace"
workspace="$(CDPATH= cd -- "$workspace" && pwd -P)"

[ -f "$env_file" ] || fail "environment file not found: $env_file (set VIBECODE_ENV_FILE to override)"
[ -r "$env_file" ] || fail "environment file is not readable: $env_file"
env_file="$(CDPATH= cd -- "$(dirname -- "$env_file")" && pwd -P)/$(basename -- "$env_file")"
command -v docker >/dev/null 2>&1 || fail "docker command not found on the host"

if [ -n "$docker_host" ]; then
  docker info >/dev/null 2>&1 ||
    fail "cannot connect to remote Docker daemon: $docker_host (check DOCKER_HOST and the host Docker client's credentials)"
  set -- docker run --rm --name vibecode-aio \
    --env-file "$env_file" \
    --env "DOCKER_HOST=$docker_host"
else
  [ -e "$docker_socket" ] || fail "Docker socket not found: $docker_socket (start Docker or set VIBECODE_DOCKER_SOCKET)"
  [ -S "$docker_socket" ] || fail "Docker socket path is not a Unix socket: $docker_socket"
  docker -H "unix://$docker_socket" info >/dev/null 2>&1 ||
    fail "cannot connect to Docker through: $docker_socket (check that Docker is running and your user can access the socket)"

  set -- docker -H "unix://$docker_socket" run --rm --name vibecode-aio \
    --env-file "$env_file" \
    --env DOCKER_HOST=

  socket_gid="${VIBECODE_DOCKER_GID:-}"
  case "$(uname -s)" in
    Linux)
      if [ -z "$socket_gid" ]; then
        socket_gid="$(stat -c '%g' "$docker_socket")" ||
          fail "cannot determine Docker socket group; set VIBECODE_DOCKER_GID"
      fi
      ;;
    Darwin)
      # Docker Desktop and OrbStack expose the mounted socket as root-owned in the VM.
      socket_gid="${socket_gid:-0}"
      ;;
    *)
      fail "unsupported host platform: $(uname -s) (use Linux, WSL2, or macOS)"
      ;;
  esac
  case "$socket_gid" in
    ''|*[!0-9]*) fail "Docker socket group must be a numeric GID: $socket_gid" ;;
  esac
  set -- "$@" --group-add "$socket_gid"

  set -- "$@" --mount "type=bind,\"src=$docker_socket\",dst=/var/run/docker.sock"
fi

set -- "$@" \
  --mount "type=bind,\"src=$workspace\",\"dst=$workspace\"" \
  --workdir "$workspace" \
  -p 3000:3000 \
  -p 20128:20128 \
  -v vibecode-home:/home/vibecoder \
  "$image"

exec "$@"
