# The live ISO and the prebuilt installed system it carries.
#
# `nix build .#iso.live` builds the live medium; the ISO's installer copies
# the already-built `nixosConfigurations.installed` closure to the target, so
# installation needs no network and no evaluation. There is no per-host ISO
# and no enrollment plumbing.
{ inputs, config, ... }:
let
  installed = config.flake.nixosConfigurations.installed;
  installedToplevel = installed.config.system.build.toplevel;

  liveIso = config.flake.nixosConfigurations.live.extendModules {
    modules = [
      ../distro/iso.nix
      ../distro/installer.nix
      {
        distro.installer.enable = true;
        distro.installer.installedSystem = "${installedToplevel}";
        distro.installer.flakeSource = "${inputs.self}";
        environment.etc."nixos-config".source = inputs.self;
        isoImage.storeContents = [ installedToplevel ];
      }
    ];
  };
in
{
  flake.isoConfig.live = liveIso;
  flake.iso.live = liveIso.config.system.build.isoImage;
}
