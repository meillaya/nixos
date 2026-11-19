{ pkgs, user, lib, ... }:
{
  imports = [ ../linux/home-manager.nix ];

  home = {
    enableNixpkgsReleaseCheck = false;
    username = user.identity.name;
    homeDirectory = user.identity.home;
    packages = pkgs.callPackage ./packages.nix {};
    file = (import ./files.nix { homeDirectory = user.identity.home; }) // {
      # The NixOS workstations show the NixOS snowflake. The shared profile
      # keeps Snoopy for macOS, and massive stays on Snoopy through that shared
      # profile; only this NixOS payload forces the Linux config.
      ".config/fastfetch/config.jsonc".source =
        lib.mkForce ../shared/config/fastfetch/linux.jsonc;
    };
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
