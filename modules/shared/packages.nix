{ pkgs, includeDocker ? true }:

with pkgs;
[
  # General packages for development and system management
  ast-grep
  aria2
  bash-completion
  bat
  bear
  btop
  bun
  ccache
  coreutils
  duf
  eza
  fastfetch
  gdb
  killall
  openssh
  pipx
  restic
  rsync
  resvg
  sqlite
  wget
  zip

  # Encryption and security tools
  gnupg
  libfido2
  nix-direnv

  # Media-related packages
  emacs-all-the-icons-fonts
  dejavu_fonts
  ffmpeg
  fd
  fira-sans
  font-awesome
  hack-font
  nerd-fonts.fira-code
  noto-fonts
  noto-fonts-color-emoji
  meslo-lgs-nf

  # Node.js development tools
  nodejs_24

  # Text and terminal utilities
  htop
  jetbrains-mono
  jq
  glances
  micro
  ncdu
  ranger
  ripgrep
  ruff
  superfile
  tectonic
  tldr
  tokei
  tree
  tmux
  unrar
  unzip
  yazi
  zellij
  zoxide
  zsh-powerlevel10k

  # Development tools
  curl
  devenv
  gh
  git-filter-repo
  act
  actionlint
  terraform
  kubectl
  kind
  kubernetes-helm
  awscli2
]
++ [
  lazygit
  mcp-nixos
  fzf
  direnv
  flyctl
  railway
  podman
  vagrant
  zed-editor

  # Programming languages and runtimes
  beamPackages.elixir
  beamPackages.erlang
  go
]
++ pkgs.lib.optionals (pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.iverilog) [
  iverilog
]
++ [
  gopls
  jdt-language-server
  nil
  nixd
  basedpyright
  rustc
  cargo
  rust-analyzer
  # Java 21 LTS — keep as the profile's only JDK: the Android projects' Gradle
  # daemon JVM criteria require "Java 21" and a second JDK would collide on
  # bin/java. For a newer JDK use a per-project `nix shell nixpkgs#openjdk25`.
  openjdk
  jdt-language-server
  gradle
  maven
  pandoc
  taplo
  typescript-language-server
  valkey
  vscode-langservers-extracted
  yaml-language-server
  zls

  # Python packages
  python3
  virtualenv
  zig
]
++ pkgs.lib.optionals includeDocker [
  # Cloud-related tools and SDKs
  docker
  docker-compose
]
