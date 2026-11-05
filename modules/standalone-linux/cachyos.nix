# CachyOS-specific system state for the `massive` standalone host.
#
# system-manager cannot install pacman packages, so this module declares the
# package set and one oneshot unit reconciles it. The unit only acts when a
# package is missing or a removal target is present, and it never refreshes the
# sync database, because `pacman -Sy` without a full upgrade is unsupported.
#
# The SDDM theme stays inside the Nix store. /etc/sddm.conf.d points ThemeDir at
# the system-manager profile, so no theme files are copied into /usr/share.
{ config, lib, pkgs, ... }:

let
  cfg = config.standalone.cachyos;

  thyx = pkgs.callPackage ../../pkgs/thyx.nix {
    preset = cfg.thyx.preset;
  };

  pacman = "/usr/bin/pacman";

  managedPackages = cfg.packages ++ lib.optionals cfg.thyx.enable cfg.thyx.packages;

  bootstrapScript = pkgs.writeShellScript "cachyos-bootstrap" ''
    set -euo pipefail

    # system-manager gives the unit a Nix-only PATH. pacman initializes gpgme,
    # and gpgme locates the distribution's gpg through PATH, so restore the host
    # paths before any pacman call. The ExecStart path and this script remain
    # absolute Nix store paths.
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

    install=(${lib.escapeShellArgs managedPackages})
    missing=()

    for package in "''${install[@]}"; do
      if ! ${pacman} -Qq "$package" >/dev/null 2>&1; then
        missing+=("$package")
      fi
    done

    if (( ''${#missing[@]} > 0 )); then
      echo "cachyos-bootstrap: installing ''${missing[*]}"
      ${pacman} -S --needed --noconfirm --noprogressbar -- "''${missing[@]}"
    fi

    remove=(${lib.escapeShellArgs cfg.removePackages})
    installed=()

    for package in "''${remove[@]}"; do
      if ${pacman} -Qq "$package" >/dev/null 2>&1; then
        installed+=("$package")
      fi
    done

    if (( ''${#installed[@]} > 0 )); then
      echo "cachyos-bootstrap: removing ''${installed[*]}"
      ${pacman} -R --nosave --noconfirm -- "''${installed[@]}"
    fi
  '';
in
{
  options.standalone.cachyos = {
    enable = lib.mkEnableOption "the CachyOS package bootstrap and SDDM theme";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "yay"
        "cachyos-gaming-meta"
        "cachyos-gaming-applications"
        "wine-mono"
        "winetricks"
        "mangohud"
        "gamemode"
        "lib32-gamemode"
      ];
      description = "Arch packages the CachyOS host must have.";
    };

    removePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "fish"
        "cachyos-fish-config"
        "fish-autopair"
        "fish-pure-prompt"
        "fisher"
      ];
      description = "Arch packages the CachyOS host must not have.";
    };

    thyx = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to install and select the Thyx SDDM theme.";
      };

      preset = lib.mkOption {
        type = lib.types.enum [
          "blush"
          "cinder"
          "gilded"
          "malachite"
          "sakura"
        ];
        default = "blush";
        description = "Thyx preset copied over theme.conf.";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "sddm"
          "qt6-declarative"
          "qt6-multimedia"
          "qt6-multimedia-ffmpeg"
          "qt6-5compat"
          "qt6-svg"
        ];
        description = "Arch packages that provide the SDDM greeter and its Qt QML modules.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional cfg.thyx.enable thyx;

    environment.etc = {
      # Noctalia starts desktop apps with systemd-run and copies its own
      # environment into the unit. Steam then prepends its runtime to
      # LD_LIBRARY_PATH. The Nix coreutils on the inherited PATH load the host
      # libc under that library path, and Steam's shell helpers fail on
      # dirname. Give the Steam unit the host tools instead.
      "systemd/user/app-steam@.service.d/10-system-manager-path.conf".text = ''
        [Service]
        Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
      '';
    } // lib.optionalAttrs cfg.thyx.enable {
      "sddm.conf.d/00-system-manager-theme.conf".text = ''
        [Theme]
        Current=thyx
        ThemeDir=/run/system-manager/sw/share/sddm/themes
      '';

      "fonts/conf.d/10-system-manager.conf".text = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <dir>/run/system-manager/sw/share/fonts</dir>
        </fontconfig>
      '';
    };

    systemd.services = {
      cachyos-bootstrap = {
        description = "Install the CachyOS gaming packages and remove the fish stack";
        wantedBy = [ "system-manager.target" ];
        before = [ "system-manager.target" "display-manager.service" ];
        after = [ "network.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = bootstrapScript;
        };
      };
    } // lib.optionalAttrs cfg.thyx.enable {
      system-manager-fonts = {
        description = "Refresh the font cache for the system-manager profile";
        wantedBy = [ "system-manager.target" ];
        before = [ "system-manager.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.fontconfig}/bin/fc-cache -f";
        };
      };
    };
  };
}
