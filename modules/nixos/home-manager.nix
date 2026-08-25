{ pkgs, user, ... }:
{
  imports = [ ../linux/home-manager.nix ];

  home = {
    enableNixpkgsReleaseCheck = false;
    username = user.identity.name;
    homeDirectory = user.identity.home;
    packages = pkgs.callPackage ./packages.nix {};
    file = import ./files.nix { homeDirectory = user.identity.home; };
    stateVersion = "21.05";
  };

  # Use a dark theme
  gtk = {
    enable = true;
    iconTheme = {
      name = "Adwaita-dark";
      package = pkgs.adwaita-icon-theme;
    };
    theme = {
      name = "Adwaita-dark";
      package = pkgs.adwaita-icon-theme;
    };
  };

  # Noctalia owns Niri's bar, notifications, screen lock, and wallpaper.
  services.udiskie.enable = true;

  programs.gpg.enable = true;

}
