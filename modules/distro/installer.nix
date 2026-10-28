# The offline installer carried by the live ISO.
{ config, lib, pkgs, ... }:
{
  options.distro.installer = {
    enable = lib.mkEnableOption "the live ISO installer";
    installedSystem = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Store path of the prebuilt installed system to copy.";
    };
    flakeSource = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Store path of the flake source copied to /etc/nixos.";
    };
  };

  config = lib.mkIf config.distro.installer.enable {
    assertions = [
      {
        assertion = config.distro.installer.installedSystem != null;
        message = "the installer needs a prebuilt installed system";
      }
      {
        assertion = config.distro.installer.flakeSource != null;
        message = "the installer needs the flake source for /etc/nixos";
      }
    ];

    environment.systemPackages = [
      (pkgs.callPackage ../../pkgs/distro-installer.nix {
        installedSystem = config.distro.installer.installedSystem;
        flakeSource = config.distro.installer.flakeSource;
        inherit (config.distro) labels;
        inherit (config.distro) liveUser;
      })
      config.system.build.nixos-install
      config.system.build.nixos-generate-config
      pkgs.nixos-enter
      pkgs.btrfs-progs
      pkgs.dosfstools
      pkgs.util-linux
      pkgs.python3
    ];
  };
}
