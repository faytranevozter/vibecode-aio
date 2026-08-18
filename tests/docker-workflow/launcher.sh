#!/bin/sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
launcher="$repo_root/scripts/run-with-docker.sh"
tmp_dir="$(mktemp -d)"
socket_pid=""
env_created=0

cleanup() {
  if [ -n "$socket_pid" ]; then
    kill "$socket_pid" >/dev/null 2>&1 || true
  fi
  if [ "$env_created" = 1 ]; then
    rm -f "$repo_root/.env"
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$tmp_dir/bin" "$tmp_dir/workspace,with-comma"
workspace="$(CDPATH= cd -- "$tmp_dir/workspace,with-comma" && pwd -P)"
if [ ! -e "$repo_root/.env" ]; then
  : > "$repo_root/.env"
  env_created=1
fi

cat > "$tmp_dir/bin/docker" <<'EOF'
#!/bin/sh
for arg do
  if [ "$arg" = info ]; then
    [ "${FAKE_DOCKER_INFO_FAIL:-0}" != 1 ]
    exit
  fi
done
printf '%s\n' "$@"
EOF

cat > "$tmp_dir/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${FAKE_UNAME:-Linux}"
EOF

cat > "$tmp_dir/bin/stat" <<'EOF'
#!/bin/sh
printf '%s\n' 1234
EOF

chmod +x "$tmp_dir/bin/docker" "$tmp_dir/bin/uname" "$tmp_dir/bin/stat"

node -e '
  const net = require("net");
  const socket = process.argv[1];
  const server = net.createServer();
  server.listen(socket);
  process.on("SIGTERM", () => server.close());
' "$tmp_dir/docker.sock" &
socket_pid=$!

while [ ! -S "$tmp_dir/docker.sock" ]; do
  sleep 0.05
done

output="$({
  cd "$tmp_dir/workspace,with-comma"
  PATH="$tmp_dir/bin:$PATH" \
    VIBECODE_DOCKER_SOCKET="$tmp_dir/docker.sock" \
    "$launcher"
})"

assert_arg() {
  printf '%s\n' "$output" | grep -Fqx -- "$1"
}

assert_no_arg() {
  if printf '%s\n' "$output" | grep -Fqx -- "$1"; then
    printf '%s\n' "unexpected launcher argument: $1" >&2
    exit 1
  fi
}

assert_arg run
assert_arg "unix://$tmp_dir/docker.sock"
assert_arg --rm
assert_arg --name
assert_arg vibecode-aio
assert_arg --env-file
assert_arg "$repo_root/.env"
assert_arg --group-add
assert_arg 1234
assert_arg "type=bind,\"src=$tmp_dir/docker.sock\",dst=/var/run/docker.sock"
assert_arg "type=bind,\"src=$workspace\",\"dst=$workspace\""
assert_arg --workdir
assert_arg "$workspace"
assert_arg 3000:3000
assert_arg 20128:20128
assert_arg vibecode-home:/home/vibecoder
assert_arg ghcr.io/faytranevozter/vibecode-aio:debian

override_env="$tmp_dir/custom.env"
: > "$override_env"
override_env="$(CDPATH= cd -- "$(dirname -- "$override_env")" && pwd -P)/$(basename -- "$override_env")"
output="$(PATH="$tmp_dir/bin:$PATH" \
  VIBECODE_WORKSPACE="$tmp_dir/workspace,with-comma" \
  VIBECODE_ENV_FILE="$override_env" \
  VIBECODE_DOCKER_SOCKET="$tmp_dir/docker.sock" \
  VIBECODE_DOCKER_GID=4321 \
  VIBECODE_IMAGE=vibecode-aio:test \
  "$launcher")"
assert_arg "$override_env"
assert_arg 4321
assert_arg vibecode-aio:test

local_env="$tmp_dir/local.env"
printf '%s\n' 'DOCKER_HOST=tcp://ignored.example.test:2376' > "$local_env"
local_env="$(CDPATH= cd -- "$(dirname -- "$local_env")" && pwd -P)/$(basename -- "$local_env")"
output="$(PATH="$tmp_dir/bin:$PATH" \
  VIBECODE_WORKSPACE="$tmp_dir/workspace,with-comma" \
  VIBECODE_ENV_FILE="$local_env" \
  VIBECODE_DOCKER_SOCKET="$tmp_dir/docker.sock" \
  "$launcher")"
assert_arg 'DOCKER_HOST='

output="$(PATH="$tmp_dir/bin:$PATH" \
  FAKE_UNAME=Darwin \
  VIBECODE_WORKSPACE="$tmp_dir/workspace,with-comma" \
  VIBECODE_ENV_FILE="$override_env" \
  VIBECODE_DOCKER_SOCKET="$tmp_dir/docker.sock" \
  "$launcher")"
assert_arg --group-add
assert_arg 0

output="$(PATH="$tmp_dir/bin:$PATH" \
  FAKE_UNAME=Darwin \
  VIBECODE_WORKSPACE="$tmp_dir/workspace,with-comma" \
  VIBECODE_ENV_FILE="$override_env" \
  VIBECODE_DOCKER_SOCKET="$tmp_dir/docker.sock" \
  VIBECODE_DOCKER_GID=4321 \
  "$launcher")"
assert_arg --group-add
assert_arg 4321

output="$(PATH="$tmp_dir/bin:$PATH" \
  DOCKER_HOST="unix://$tmp_dir/docker.sock" \
  VIBECODE_WORKSPACE="$tmp_dir/workspace,with-comma" \
  VIBECODE_ENV_FILE="$override_env" \
  "$launcher")"
assert_arg --group-add
assert_arg 1234
assert_arg "type=bind,\"src=$tmp_dir/docker.sock\",dst=/var/run/docker.sock"
assert_no_arg "DOCKER_HOST=unix://$tmp_dir/docker.sock"

output="$(PATH="$tmp_dir/bin:$PATH" \
  DOCKER_HOST=tcp://docker.example.test:2376 \
  VIBECODE_WORKSPACE="$tmp_dir/workspace,with-comma" \
  VIBECODE_ENV_FILE="$override_env" \
  VIBECODE_DOCKER_SOCKET="$tmp_dir/missing.sock" \
  "$launcher")"
assert_arg --env
assert_arg 'DOCKER_HOST=tcp://docker.example.test:2376'
assert_no_arg --group-add
assert_no_arg 'type=bind,"src='$tmp_dir'/missing.sock",dst=/var/run/docker.sock'

if error="$(PATH="$tmp_dir/bin:$PATH" \
  DOCKER_HOST=ssh://docker.example.test \
  FAKE_DOCKER_INFO_FAIL=1 \
  VIBECODE_ENV_FILE="$override_env" \
  "$launcher" 2>&1)"; then
  printf '%s\n' 'expected an unreachable remote Docker daemon to fail' >&2
  exit 1
fi
printf '%s\n' "$error" | grep -Fq \
  'cannot connect to remote Docker daemon: ssh://docker.example.test'
printf '%s\n' "$error" | grep -Fq \
  "check DOCKER_HOST and the host Docker client's credentials"

if error="$(PATH="$tmp_dir/bin:$PATH" \
  VIBECODE_ENV_FILE="$override_env" \
  VIBECODE_DOCKER_SOCKET="$tmp_dir/docker.sock" \
  VIBECODE_DOCKER_GID=not-a-gid \
  "$launcher" 2>&1)"; then
  printf '%s\n' 'expected a nonnumeric Docker socket GID to fail' >&2
  exit 1
fi
printf '%s\n' "$error" | grep -Fq \
  'Docker socket group must be a numeric GID: not-a-gid'

if error="$(PATH="$tmp_dir/bin:$PATH" \
  VIBECODE_ENV_FILE="$override_env" \
  VIBECODE_DOCKER_SOCKET="$tmp_dir/missing.sock" \
  "$launcher" 2>&1)"; then
  printf '%s\n' 'expected a missing Docker socket to fail' >&2
  exit 1
fi
printf '%s\n' "$error" | grep -Fq \
  'Docker socket not found:'
printf '%s\n' "$error" | grep -Fq \
  'start Docker or set VIBECODE_DOCKER_SOCKET'

if error="$(PATH="$tmp_dir/bin:$PATH" \
  FAKE_DOCKER_INFO_FAIL=1 \
  VIBECODE_ENV_FILE="$override_env" \
  VIBECODE_DOCKER_SOCKET="$tmp_dir/docker.sock" \
  "$launcher" 2>&1)"; then
  printf '%s\n' 'expected an unusable Docker socket to fail' >&2
  exit 1
fi
printf '%s\n' "$error" | grep -Fq \
  'cannot connect to Docker through:'
