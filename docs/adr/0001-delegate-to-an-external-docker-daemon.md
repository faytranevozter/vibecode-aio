# Delegate Docker Workflows to an External Daemon

Vibecode ships Docker's CLI, Buildx, and Compose plugins, but no Docker daemon. Docker access is disabled by default and becomes available only when an operator explicitly mounts a daemon socket and grants the non-root `vibecoder` user its group; this keeps ordinary startup isolated and avoids the extra privilege, storage, supervision, and nested-runtime complexity of true Docker-in-Docker, while acknowledging that an enabled client has effectively administrative control of the external Docker host.
