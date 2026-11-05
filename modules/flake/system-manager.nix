# system-manager wiring: the declarative system level for the standalone
# (non-NixOS) host.
#
# Home Manager owns the `massive` user payload. It cannot own anything under
# /etc, any systemd system unit, or any pacman package on a foreign
# distribution, so the hostname, the tailscaled service, the login account, the
# CachyOS package bootstrap, and the OpenRGB system package live in
# `systemConfigs.massive` instead, built from modules/standalone-linux/system.nix.
# system-manager uses the NixOS module system, so that file reads like a NixOS
# system module while only owning the files and units of its own generation.
#
# Apply from a checkout:
#
#   nix run github:numtide/system-manager -- switch --flake .#massive --sudo
#
# `--flake .#massive` selects `systemConfigs.massive`; system-manager prefixes
# the attribute with `systemConfigs` itself, so pass the bare host name.
{ inputs, ... }:
let
  inherit (inputs) system-manager;

  # `massive` is a Den home, so its user identity lives in inventory.nix.
  # system-manager sits outside Den and needs the same name, uid, gid, and home
  # for the account, the data-disk mount point, and the login shell, so this
  # reads the same record instead of repeating literals.
  inventory = import ../aspects/inventory.nix { };
  home = inventory.den.homes.x86_64-linux.massive;
in
{
  flake.systemConfigs.massive = system-manager.lib.makeSystemConfig {
    modules = [
      ../standalone-linux/system.nix
      {
        standalone.hostName = "massive";
        standalone.userName = home.userName;
        standalone.userUid = home.identity.uid;
        standalone.userGid = home.identity.gid;
        standalone.homeDirectory = home.homeDirectory;
        standalone.dataDisk.enable = true;
        standalone.cachyos.enable = true;
        standalone.openrgb.enable = true;
      }
    ];
  };
}
