# Rootless containers

Docker and Podman run rootless on every host this repo manages. The policy lives
in `modules/aspects/rootless-containers.nix`.

## NixOS hosts

`virtualisation.docker.rootless` runs a per-user dockerd that exports
`DOCKER_HOST`, and podman provides its rootless user socket. The rootful docker
daemon, podman's system socket, and the root-equivalent `docker` group are all
off. The user manager lingers, so both sockets work without an interactive
login.

## Standalone Linux home

`massive` includes `rootless-containers-standalone`, which gives a foreign
distribution with Nix the rootless podman user socket plus a docker-compatible
`DOCKER_HOST`, so docker clients never need a root daemon there either. The
shared aspect has no Home Manager branch and does not inspect `osConfig`.

## Darwin

Left alone. Docker Desktop, colima, and `podman machine` already run the engine
inside a VM rather than as a host root process.
