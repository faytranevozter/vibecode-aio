# Delegate Docker Workflows to an External Daemon

Vibecode ships Docker's CLI, Buildx, and Compose plugins, but no Docker daemon. Docker access is disabled by default and becomes available only when an operator explicitly mounts a daemon socket and grants the non-root `vibecoder` user the socket's group as exposed inside the container. This keeps ordinary startup isolated and avoids the extra privilege, storage, supervision, and nested-runtime complexity of true Docker-in-Docker, while acknowledging that an enabled client has effectively administrative control of the external Docker host.

Daemon-side bind mounts resolve paths on the daemon host, not in the Vibecode container. Docker-enabled launchers therefore expose a selected host workspace at the same absolute path inside Vibecode, preserving ordinary bind-mount and relative Compose behavior without path translation. Projects stored only in Vibecode's named home volume must instead share that named volume explicitly.
