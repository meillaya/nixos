{
  inputs,
  userName,
  homeDirectory,
}:
{ config, pkgs, lib, ... }:

let
  standalone-files = import ./files.nix { inherit pkgs; };
in
{
  imports = [ ../linux/home-manager.nix ];

  # Trust the binary-cache union at the user level so `nix run .#home-switch`
  # substitutes from signed caches instead of rebuilding. `mei` is a daemon
  # trusted-user (`/etc/nix/nix.custom.conf`), so a trusted user's
  # `extra-substituters` in the user config is honored. The CachyOS host runs
  # Determinate Nix; ~/.config/nix/nix.conf is its user-level config.
  # xdg.configFile (not home.file) so HM resolves the path instead of creating
  # a literal `~` directory.
  xdg.configFile."nix/nix.conf".text = ''
    # BEGIN nix-caching-zen-browser: binary-cache union (managed by HM)
    extra-substituters = https://noctalia.cachix.org https://nix-community.cachix.org https://cache.nixos.org
    extra-trusted-public-keys = noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
    # END nix-caching-zen-browser
  '';

  # Podman is the Nix-provided package on a foreign distro: CachyOS packages
  # no podman and therefore no /etc/containers, which podman searches for its
  # signature policy and registry list. Without these user-level files every
  # `podman run`/pull fails with "no policy.json file found". The policy is
  # the upstream containers/image default (no signature requirement) and the
  # registry list makes unqualified image names resolve against docker.io.
  xdg.configFile."containers/policy.json".text = builtins.toJSON {
    default = [ { type = "insecureAcceptAnything"; } ];
  };
  xdg.configFile."containers/registries.conf".text = ''
    unqualified-search-registries = ["docker.io"]
  '';

  home = {
    enableNixpkgsReleaseCheck = false;
    username = lib.mkDefault userName;
    homeDirectory = lib.mkDefault homeDirectory;
    packages = import ./packages.nix { inherit pkgs inputs; };
    file = standalone-files;
    sessionVariables = {
      BROWSER = "zen-beta";
      TERM = "xterm-256color";
      QT_QPA_PLATFORMTHEME = "qt5ct";
      GTK_THEME = "adw-gtk3-dark";
      # Java 21 (LTS), matching the Gradle daemon JVM criteria used by the
      # Android projects. Do not bump: JDK 25/26 would not satisfy a
      # "Compatible with Java 21" toolchain criterion and would collide with
      # this JDK on bin/java in the same profile.
      JAVA_HOME = "${pkgs.openjdk.home}";
    };
    sessionPath = [
      "${config.home.homeDirectory}/.local/bin"
    ];
    stateVersion = "25.11";
  };


  targets.genericLinux.enable = true;
  fonts.fontconfig = {
    enable = true;
    # The desktop theme (GTK + KDE) declares Fira Sans as the UI font; make
    # the generic `sans-serif` family resolve to it too so apps that ask for
    # a generic family (e.g. mpv OSD, Chromium fallbacks) render the same
    # system font instead of silently substituting Noto Sans.
    defaultFonts.sansSerif = [ "Fira Sans" ];
  };

  programs = {
    gpg.enable = true;
    home-manager.enable = true;
  };
}
