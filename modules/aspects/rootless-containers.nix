# Rootless container engines.
#
# Docker's stock NixOS module starts a system-wide daemon that runs as root,
# and the `docker` group that unlocks its socket is root-equivalent. This
# aspect makes rootless the only arrangement the flake ever produces:
#
#   NixOS  * the rootful daemon stays off and the user is not in the `docker`
#            group; `virtualisation.docker.rootless` runs dockerd as a per-user
#            service and exports DOCKER_HOST;
#          * podman ships with its rootless user socket, and the stock system
#            (root) socket is pinned off.
#   HM     * a standalone (non-NixOS) home gets the rootless podman user socket
#            plus a docker-compatible DOCKER_HOST, so docker clients never need
#            a root daemon on a foreign distro.
#   darwin * deliberately untouched: Docker Desktop/colima and `podman machine`
#            already run the engine inside a VM, never as a host root process.
{ den, ... }:
{
  den.aspects.rootless-containers = {
    nixos =
      { host, config, lib, ... }:
      let
        user = host.machine.identity.name;
      in
      {
        virtualisation.docker.enable = lib.mkForce false;
        virtualisation.docker.rootless = {
          enable = true;
          setSocketVariable = true;
          daemon.settings."log-driver" = "json-file";
        };

        virtualisation.podman.enable = true;
        # The upstream podman module also starts a system-wide socket whose
        # service runs as root; the rootless user socket replaces it.
        virtualisation.podman.dockerSocket.enable = lib.mkForce false;
        systemd.sockets.podman.wantedBy = lib.mkForce [ ];

        # Rootless sockets live in the user manager; lingering keeps them
        # reachable outside an interactive login session.
        users.users.${user}.linger = true;

        assertions = [
          {
            assertion = config.virtualisation.docker.rootless.enable;
            message = "rootless-containers: the rootless docker daemon must stay enabled";
          }
          {
            assertion = !config.virtualisation.docker.enable;
            message = "rootless-containers: the rootful docker daemon must never be enabled";
          }
          {
            assertion = !(lib.elem "docker" config.users.users.${user}.extraGroups);
            message = "rootless-containers: docker group membership grants root-equivalent socket access";
          }
          {
            assertion = !config.virtualisation.podman.dockerSocket.enable;
            message = "rootless-containers: podman's root system socket must never be enabled";
          }
        ];
      };

    homeManager =
      { pkgs, lib, osConfig ? null, ... }:
      lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && osConfig == null) {
        # Standalone Home Manager host (a foreign distro with Nix installed):
        # the Nix podman package is the only engine, so docker-compatible
        # clients talk to its per-user rootless socket instead of a root
        # daemon. On NixOS the system module owns both sockets already.
        systemd.user.packages = [ pkgs.podman ];
        systemd.user.sockets.podman = {
          Unit.Description = "Podman rootless API socket";
          Socket = {
            ListenStream = "%t/podman/podman.sock";
            SocketMode = "0660";
          };
          Install.WantedBy = [ "sockets.target" ];
        };
        home.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
      };
  };
}
