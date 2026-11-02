# The single place a distro name, id, hostname, and storage labels live.
{ config, lib, ... }:
{
  options.distro = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "MeiNixOS";
      description = "Name shown in the boot menu and /etc/os-release.";
    };
    id = lib.mkOption {
      type = lib.types.str;
      default = "meinix";
      description = "Lowercase id used for image names and labels.";
    };
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "Hostname the installer bakes into the installed system.";
    };
    liveUser = lib.mkOption {
      type = lib.types.str;
      default = "mei";
      description = "Desktop user the live ISO logs in as.";
    };
    labels = {
      boot = lib.mkOption {
        type = lib.types.str;
        default = "NIXBOOT";
        description = "FAT label of the EFI system partition.";
      };
      root = lib.mkOption {
        type = lib.types.str;
        default = "NIXROOT";
        description = "Btrfs label of the installed root filesystem.";
      };
    };
  };

  config = {
    system.nixos.distroName = config.distro.name;
    system.nixos.distroId = config.distro.id;
    system.image.id = config.distro.id;
    system.image.version = "dev";
  };
}
