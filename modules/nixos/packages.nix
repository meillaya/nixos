{ pkgs }:

with pkgs;
let
  shared-packages = import ../shared/packages.nix { inherit pkgs; };
  linux-packages = import ../linux/packages.nix { inherit pkgs; };
in
shared-packages ++ linux-packages ++ [

  # Security and authentication
  yubikey-agent

  # App and package management
  appimage-run
  gnumake
  cmake
  home-manager

  # Testing and development tools
  libtool # for Emacs vterm

  # Screenshot and recording tools
  flameshot

  # Text and terminal utilities
  unixtools.ifconfig
  unixtools.netstat
  xclip # For the org-download package in Emacs
  xwininfo # Provides a cursor to click and learn about windows
  xrandr

  # File and system utilities
  inotify-tools # inotifywait, inotifywatch - For file system events
  pcmanfm # File browser
]
  ++ lib.optionals (stdenv.hostPlatform.system == "x86_64-linux") [
  # Generic Linux keeps gaming launchers host-managed; NixOS owns Heroic.
  heroic
]
  ++ lib.optionals (lib.meta.availableOn stdenv.hostPlatform google-chrome) [
  # Other utilities
  google-chrome
]
  ++ [

  # PDF viewer
  zathura

  # Development tools
  firefox

  # Music and entertainment
]
