# system-manager wiring: the declarative system level for the standalone
# (non-NixOS) host.
#
# Home Manager owns the `massive` user payload. It cannot own anything under
# /etc or any systemd system unit on a foreign distribution, so the hostname and
# the tailscaled service live in `systemConfigs.massive` instead, built from
# modules/standalone-linux/system.nix. system-manager uses the NixOS module
# system, so that file reads like a NixOS system module while only owning the
# files and units of its own generation.
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
  # system-manager sits outside Den and needs the name to own the data-disk
  # mount point, so this reads the same record instead of repeating a literal.
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
        standalone.dataDisk.enable = true;
      }
    ];
  };
}
