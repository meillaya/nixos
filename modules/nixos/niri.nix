{ inputs }:
{ pkgs, ... }:

{
  programs = {
    niri = {
      enable = true;
      package = pkgs.niri;
    };
    xwayland.enable = true;
  };

  security.polkit.enable = true;
  hardware.bluetooth.enable = true;

  networking.networkmanager.enable = true;

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      kdePackages.xdg-desktop-portal-kde
    ];
    config.common = {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [
        "kde"
        "gtk"
      ];
      "org.freedesktop.impl.portal.AppChooser" = [
        "kde"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Settings" = [
        "kde"
        "gtk"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    kdePackages.polkit-kde-agent-1
    niri
    xwayland-satellite
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
