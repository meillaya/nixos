# Per-host NixOS installer ISOs.
#
# Exposes `nix build .#iso.<host>` (flake output `iso.<host>`), which is
# shorthand for `.#nixosConfigurations.<host>.config.system.build.isoImage`.
# Exactly ONE ISO variant (installer) per NixOS host: remembrance, antagony.
{ lib, config, ... }:
let
  isoHosts = [ "remembrance" "antagony" ];

  # Build the installer ISO for a host. The hosts disable the initrd while
  # their boot state is "disabled" (pending enrollment), but an installer
  # ISO must be bootable, so re-enable it for the ISO variant only.
  isoFor = host:
    (config.flake.nixosConfigurations.${host}.extendModules {
      modules = [
        {
          boot.initrd.enable = lib.mkForce true;
        }
      ];
    }).config.system.build.images.iso;
in
{
  flake.iso = lib.genAttrs isoHosts isoFor;
}