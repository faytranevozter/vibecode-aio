#!/bin/sh
set -eu

suffix="${GITHUB_RUN_ID:-local}-$$"
child_image="vibecode-child-smoke:${suffix}"
child_container="vibecode-child-smoke-${suffix}"
bind_container="vibecode-bind-smoke-${suffix}"

cleanup() {
  docker rm -f "$child_container" >/dev/null 2>&1 || true
  docker rm -f "$bind_container" >/dev/null 2>&1 || true
  docker image rm -f "$child_image" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

[ "$(id -u)" = 1000 ]
docker --version
docker buildx version
docker compose version

docker buildx build \
  --load \
  --tag "$child_image" \
  tests/docker-workflow

output="$(docker run --name "$child_container" --rm "$child_image")"
[ "$output" = "vibecode child container ready" ]

output="$(docker run --name "$bind_container" --rm \
  --mount "type=bind,src=$PWD/tests/docker-workflow/workspace-marker.txt,dst=/workspace-marker.txt,readonly" \
  "$child_image" cat /workspace-marker.txt)"
[ "$output" = "same-path workspace is visible to child containers" ]
