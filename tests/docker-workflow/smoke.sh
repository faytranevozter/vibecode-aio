#!/bin/sh
set -eu

suffix="${GITHUB_RUN_ID:-local}-$$"
child_image="vibecode-child-smoke:${suffix}"
child_container="vibecode-child-smoke-${suffix}"
bind_container="vibecode-bind-smoke-${suffix}"
compose_project="vibecode-compose-smoke-${suffix}"
compose_file="$PWD/tests/docker-workflow/compose.yml"

compose() {
  docker compose --project-name "$compose_project" --file "$compose_file" "$@"
}

cleanup() {
  test_status=$?
  cleanup_status=0
  trap - EXIT HUP INT TERM
  set +e

  compose down --volumes --rmi local --remove-orphans || cleanup_status=$?
  docker rm -f "$child_container" >/dev/null 2>&1 || true
  docker rm -f "$bind_container" >/dev/null 2>&1 || true
  docker image rm -f "$child_image" >/dev/null 2>&1 || true

  if [ -n "$(docker ps --all --quiet --filter "label=com.docker.compose.project=$compose_project")" ] ||
    [ -n "$(docker network ls --quiet --filter "label=com.docker.compose.project=$compose_project")" ] ||
    [ -n "$(docker volume ls --quiet --filter "label=com.docker.compose.project=$compose_project")" ] ||
    [ -n "$(docker image ls --quiet --filter "reference=${compose_project}-*")" ]; then
    printf '%s\n' "Compose cleanup left resources for project: $compose_project" >&2
    cleanup_status=1
  fi

  if [ "$test_status" -ne 0 ]; then
    exit "$test_status"
  fi
  exit "$cleanup_status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

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

compose config --quiet
compose up --build --detach --wait

published="$(compose port web 8080)"
host_port="${published##*:}"
bridge_gateway="$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}')"
output="$(curl --fail --silent --show-error --retry 10 --retry-connrefused \
  "http://${bridge_gateway}:${host_port}")"
[ "$output" = "same-path workspace is visible to child containers" ]
