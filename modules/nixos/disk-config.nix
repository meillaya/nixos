{ config, lib, ... }:
let
  storage = config.nixConfig.storage;
  disk = storage.diskById;
  diskBasename = if disk == null then "" else disk;
in
{
  options.nixConfig.storage = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the enrolled, host-bound Disko layout.";
    };

    hostId = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Host identity bound to the reviewed storage enrollment.";
    };

    diskById = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Reviewed /dev/disk/by-id basename; never a kernel device path.";
    };
  };

  config = lib.mkIf storage.enable {
    assertions = [
      {
        assertion =
          disk != null
          && builtins.match "[A-Za-z0-9][A-Za-z0-9._:+-]{0,254}" disk != null;
        message = "enabled storage requires an enrolled by-id basename";
      }
      {
        assertion = disk != null && builtins.match ".*-part[0-9]+" disk == null;
        message = "enabled storage requires a whole-device by-id basename";
      }
      {
        assertion = storage.hostId != "";
        message = "enabled storage requires an explicit host binding";
      }
    ];

    disko.devices.disk.primary = {
      device = "/dev/disk/by-id/${diskBasename}";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            type = "EF00";
            size = "1024M";
            content = {
              type = "filesystem";
              format = "vfat";
              extraArgs = [ "-F" "32" ];
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [ "compress=zstd:3" "noatime" ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [ "compress=zstd:3" "noatime" ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [ "compress=zstd:3" "noatime" ];
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = [ "compress=zstd:3" "noatime" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
