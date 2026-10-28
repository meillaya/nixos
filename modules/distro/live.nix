# Live-session behavior. The ISO variant adds the image plumbing on top.
{ config, lib, ... }:
let
  username = config.distro.liveUser;
in
{
  users.users.${username} = {
    initialHashedPassword = lib.mkForce "";
    extraGroups = [
      "disk"
      "networkmanager"
    ];
  };

  services.openssh.enable = lib.mkForce false;
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  services.displayManager.autoLogin = {
    enable = true;
    user = username;
  };

  services.logind.settings.Login = {
    HandleLidSwitch = lib.mkForce "ignore";
    IdleAction = lib.mkForce "ignore";
  };

  # The live medium owns boot; the installed profile uses systemd-boot.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # Evaluable as a normal configuration, replaced by the ISO image media.
  fileSystems."/" = {
    device = lib.mkDefault "tmpfs";
    fsType = lib.mkDefault "tmpfs";
    options = lib.mkDefault [ "mode=0755" "size=8G" ];
  };

  networking.hostName = lib.mkForce "${config.distro.id}-live";
  system.nixos.variant_id = "live";
}
