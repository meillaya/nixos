# The offline installer carried by the live ISO.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  installer = pkgs.callPackage ../pkgs/distro-installer.nix {
    installedSystem = config.distro.installer.installedSystem;
    flakeSource = config.distro.installer.flakeSource;
    inherit (config.distro) labels;
    inherit (config.distro) liveUser;
  };

  gui = pkgs.callPackage ../pkgs/distro-installer-gui.nix {
    inherit installer;
    inherit (config.distro) liveUser;
    distroName = config.distro.name;
  };

  niriConfig = builtins.readFile ../../modules/linux/config/niri/config.kdl;
in
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
      installer
      gui
      config.system.build.nixos-install
      config.system.build.nixos-generate-config
      pkgs.nixos-enter
      pkgs.btrfs-progs
      pkgs.dosfstools
      pkgs.util-linux
      pkgs.python3
    ];

    # Open the graphical installer when the live session starts. The console
    # installer stays available from a terminal and from the quirk boot entry.
    home-manager.users.${config.distro.liveUser}.home.file.".config/niri/config.kdl".text =
      lib.mkForce
        (niriConfig + "\nspawn-at-startup \"nixos-install-gui\"\n");
  };
}
