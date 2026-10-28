# ISO image plumbing for the live medium. Imported only by flake.isoConfig.live.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    "${modulesPath}/profiles/base.nix"
  ];

  image.baseName = lib.mkForce (
    "${config.distro.id}-${config.system.nixos.release}-${pkgs.stdenv.hostPlatform.system}"
  );

  isoImage = {
    makeEfiBootable = true;
    makeUsbBootable = true;
    makeBiosBootable = true;
    volumeID = lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] config.distro.id) + "_LIVE";
    # Fast enough for a USB build; use xz for the smallest image instead.
    squashfsCompression = "zstd -Xcompression-level 15";
  };

  boot.plymouth.enable = true;
  boot.supportedFilesystems = [ "btrfs" "vfat" "ext4" "xfs" ];
  system.nixos.variant_id = "live";
}
