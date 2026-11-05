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


  # system-manager owns /run/opengl-driver (see ./system.nix), so the user-level
  # gpu module would build a second driver tree and then warn on every switch
  # that the live symlink points at the other one.
  targets.genericLinux.enable = true;
  targets.genericLinux.gpu.enable = false;
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
