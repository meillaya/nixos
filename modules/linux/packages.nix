{ pkgs, ... }:

with pkgs;
[
  # Security and authentication
  keepassxc

  # Wayland/Niri desktop
  brightnessctl
  cliphist
  ddcutil
  fontconfig
  fuzzel
  kdePackages.konsole
  kdePackages.polkit-kde-agent-1
  libnotify
  niri
  pavucontrol
  playerctl
  wl-clipboard
  wofi
  xdg-utils
  xwayland-satellite

  # KDE file manager, document viewer, and Sweet/Dr460nized Qt theming
  kdePackages.ark
  kdePackages.dolphin
  kdePackages.dolphin-plugins
  kdePackages.ffmpegthumbs
  kdePackages.kio-admin
  kdePackages.kio-extras
  kdePackages.okular
  kdePackages.partitionmanager
  kdePackages.qt6ct
  kdePackages.qtstyleplugin-kvantum
  libsForQt5.qt5ct
  libsForQt5.qtstyleplugin-kvantum

  # Cross-Linux desktop applications
  calibre
  conky
  freecad
  fsearch
  gimp
  ghostty
  halloy
  hydralauncher
  imhex
  incus
  kicad
  kitty
  libreoffice
  llama-cpp
  meld
  mission-center
  mpv
  obs-studio
  ollama
  openrgb
  ptyxis
  qbittorrent
  remmina
  tailscale
  virt-manager
  vesktop
  vlc
  wireshark
  yaak
  zathura

  # Vendored: removed upstream over gtk-engine-murrine (nixpkgs #549887)
  (pkgs.callPackage ../../pkgs/sweet.nix { })

  # Android development (android-studio is unfree: package-exceptions.json)
  android-studio
  android-tools
]
++ lib.optionals (stdenv.hostPlatform.system == "x86_64-linux") [
  hoppscotch
  obsidian
  (pkgs.callPackage ../../pkgs/elecwhat-bin.nix { })
]
