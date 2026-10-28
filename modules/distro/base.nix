# Shared overrides for the live and installed distro profiles.
#
# The distro reuses the personal Linux system module, then removes the pieces
# that must not be true on a fresh machine: personal SSH trust, tailscale and
# syncthing startup, and the personal state version.
{ config, lib, pkgs, ... }:
let
  user = config.distro.liveUser;
in
{
  imports = [ ./identity.nix ];

  services.tailscale.enable = lib.mkForce false;
  services.syncthing.enable = lib.mkForce false;

  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "i2c"
    ];
    openssh.authorizedKeys.keys = lib.mkForce [ ];
  };
  users.users.root.openssh.authorizedKeys.keys = lib.mkForce [ ];
  users.mutableUsers = true;

  system.stateVersion = lib.mkForce "26.05";
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  time.timeZone = lib.mkForce "UTC";
  i18n.defaultLocale = lib.mkForce "en_US.UTF-8";
  console.keyMap = lib.mkForce "us";
  services.xserver.xkb.layout = lib.mkForce "us";
}
