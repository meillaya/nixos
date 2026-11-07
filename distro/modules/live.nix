# Live-session behavior. The ISO variant adds the image plumbing on top.
{
  config,
  lib,
  pkgs,
  ...
}:
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
    openssh.authorizedKeys.keys = lib.mkForce [ ];
  };

  # Keep the personal services and trust anchors off the live medium.
  services.openssh.enable = lib.mkForce false;
  services.tailscale.enable = lib.mkForce false;
  services.syncthing.enable = lib.mkForce false;
  users.users.root.openssh.authorizedKeys.keys = lib.mkForce [ ];

  # The live medium uses generic locale and keyboard settings. The installed
  # profile inherits the host values instead.
  time.timeZone = lib.mkForce "UTC";
  i18n.defaultLocale = lib.mkForce "en_US.UTF-8";
  console.keyMap = lib.mkForce "us";
  services.xserver.xkb.layout = lib.mkForce "us";
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

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
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # The live root is the ISO medium, not an installed disk.
  my.storage.labels.enable = false;

  # Evaluable as a normal configuration, replaced by the ISO image media.
  fileSystems."/" = {
    device = lib.mkDefault "tmpfs";
    fsType = lib.mkDefault "tmpfs";
    options = lib.mkDefault [
      "mode=0755"
      "size=8G"
    ];
  };

  networking.hostName = lib.mkForce "${config.distro.id}-live";
  system.nixos.variant_id = "live";
}
