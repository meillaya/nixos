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

  # Node.js development tools.
  # Deliberately NOT nodejs_22/nodejs_24: nixpkgs builds Node from source on
  # aarch64-darwin, and every source-built Node (verified in-store: 22.23.3,
  # 24.16.0, 24.20.0) breaks @deepseek-ai/dsh. Its node-addon-require-builtin
  # addon pattern-matches Node's compiled internal `requireBuiltin` getter and
  # fails with `Unsupported/no-getter`, aborting host preparation at boot.
  # Only official prebuilt builds match, so use fnm for Node instead:
  #   fnm install 22 && fnm default 22
  fnm

  # pnpm is required by `dsh plugin`, which spawns a bare `pnpm` from PATH.
  # Pinned to the 11.x line deliberately: the desktop app bundles pnpm 11.7.0,
  # while nixpkgs' bare `pnpm` is 12.x, whose lockfile the app's pnpm 11 may
  # not read. 11.27.0 is the closest match available in this nixpkgs pin.
  pnpm_11

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
  # Java 21 LTS, kept as the profile's only JDK: the Android projects' Gradle
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

# zix itself, built from tools/zix. That tree is also its own flake, so the CLI
# runs without this repository:
#   nix run github:meillaya/nixos?dir=tools/zix -- --help
++ [ (pkgs.callPackage ../../tools/zix/package.nix { }) ]

# zix-managed packages (`zix add|rm`; see tools/zix/README.md)
++ (import ../../zix/managed/packages.nix { inherit pkgs; })
