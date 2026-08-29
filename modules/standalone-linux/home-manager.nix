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

  home = {
    enableNixpkgsReleaseCheck = false;
    username = lib.mkDefault userName;
    homeDirectory = lib.mkDefault homeDirectory;
    packages = (import ./packages.nix { inherit pkgs inputs; }) ++ [
      pkgs.nodejs
      ((pkgs.writeShellScriptBin "codex-wrapped" ''
        set -euo pipefail
        export SOPS_AGE_KEY_FILE="${config.home.homeDirectory}/.config/sops/age/keys.txt"
        SECRETS_FILE="${config.home.homeDirectory}/nixos/secrets/coding-agents.yaml"
        exec sops exec-env "$SECRETS_FILE" -- codex "$@"
      '') // { pname = "codex-wrapped"; })
    ];
    file = standalone-files;
    sessionVariables = {
      BROWSER = "zen-beta";
      TERM = "xterm-256color";
      QT_QPA_PLATFORMTHEME = "qt5ct";
      GTK_THEME = "adw-gtk3-dark";
      # Java 21 (LTS) — matches the Gradle daemon JVM criteria used by the
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

  home.activation.installCodingAgents = let
    npm = "${pkgs.nodejs}/bin/npm";
    curl = "${pkgs.curl}/bin/curl";
    bash = "${pkgs.bash}/bin/bash";
    tar = "${pkgs.gnutar}/bin";
    gzip = "${pkgs.gzip}/bin";
    bzip2 = "${pkgs.bzip2}/bin";
    xz = "${pkgs.xz}/bin";
    # OMO Native (Senpi engine) ships the `omo` launcher bin; needs node >= 24.
    # The activation PATH is prefixed with `tar`, `gzip`, `bzip2`, `xz`,
    # `bash`, `curl`, and `unzip` so the npm install can spawn shell helpers
    # that the HM activation PATH would otherwise exclude.
  in lib.hm.dag.entryAfter ["writeBoundary"] ''
    export PATH="${tar}:${gzip}:${bzip2}:${xz}:${pkgs.bash}/bin:${pkgs.curl}/bin:${pkgs.unzip}/bin:$PATH:$HOME/.local/bin:$HOME/.kimi-code/bin"
    install_if_missing() {
      local name="$1" cmd="$2"
      if ! command -v "$name" &>/dev/null; then
        echo "install-coding-agents: installing $name..."
        eval "$cmd"
      else
        echo "install-coding-agents: $name already present, skipping"
      fi
    }
    # npm-based installers use --force because the user's prior manual install
    # may have left symlinks/files at the npm global prefix that block overwrite.
    install_if_missing codex "${npm} install -g --force @openai/codex"
    install_if_missing omo "${npm} install -g --force omo-ai@beta"
    # lazycodex uses an interactive TUI installer and must be installed
    # manually: `npx lazycodex-ai install` per machine. The verification step
    # is `npx lazycodex-ai doctor`; it requires codex and `~/.local/bin` on PATH.
  '';

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
