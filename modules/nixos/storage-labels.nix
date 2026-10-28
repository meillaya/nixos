# Fixed filesystem-label contract shared by every installed NixOS system.
#
# The installer creates these labels on whichever disk the operator chooses,
# so no host is bound to a kernel or by-id device name. The same closure therefore
# boots from any disk prepared by the installer.
{ config, lib, ... }:
{
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXROOT";
      fsType = "btrfs";
      options = [ "subvol=@root" "compress=zstd:3" "noatime" ];
    };
    "/home" = {
      device = "/dev/disk/by-label/NIXROOT";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd:3" "noatime" ];
    };
    "/nix" = {
      device = "/dev/disk/by-label/NIXROOT";
      fsType = "btrfs";
      options = [ "subvol=@nix" "compress=zstd:3" "noatime" ];
      neededForBoot = true;
    };
    "/var/log" = {
      device = "/dev/disk/by-label/NIXROOT";
      fsType = "btrfs";
      options = [ "subvol=@log" "compress=zstd:3" "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/NIXBOOT";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };

  boot.supportedFilesystems = [ "btrfs" "vfat" ];
  boot.initrd.availableKernelModules = [ "btrfs" "vfat" ];

  # A swap partition would bind the image to the installer's partition table.
  # Compressed RAM swap keeps the disk layout to ESP plus Btrfs root.
  zramSwap.enable = true;

  assertions = [
    {
      assertion = lib.hasPrefix "/dev/disk/by-label/" config.fileSystems."/".device;
      message = "the installed root filesystem must use the shared label contract";
    }
  ];
}
