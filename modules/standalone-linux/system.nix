{ config, lib, pkgs, utils, ... }:

# System-level layer for the `massive` standalone host, built into
# `systemConfigs.massive` by modules/flake/system-manager.nix.
#
# This file owns what Home Manager cannot reach on a non-NixOS machine: the
# static hostname, the tailscaled service, the GPU driver tree that Nix
# packages expect under /run/opengl-driver, the Nix settings that the
# distribution's nix.conf includes, the 970 EVO data mount, the login account
# and its shell, the PAM helper wrapper, and the OpenRGB system package. The
# CachyOS pacman package set and the SDDM theme live in ./cachyos.nix. The
# desktop and every user package stay with ./home-manager.nix.
let
  caches = import ../../lib/nix-caches.nix;

  disk = config.standalone.dataDisk;

  # Nix packages that use EGL, GL, or VA-API read their vendor descriptions and
  # driver libraries from /run/opengl-driver. This is the package set Home
  # Manager's genericLinux module builds. system-manager owns it here because
  # system-manager may write the /etc tmpfiles rule which points at the tree,
  # and Home Manager on a foreign distribution may not.
  gpuDrivers = pkgs.buildEnv {
    name = "non-nixos-gpu";
    paths = [
      pkgs.mesa
      pkgs.libglvnd
      pkgs.libvdpau-va-gl
    ]
    ++ lib.optional (pkgs.stdenv.hostPlatform.system == "x86_64-linux") pkgs.intel-media-driver;
  };

  # systemd derives a mount unit name from the mount point, and the ownership
  # service has to order itself after exactly that unit.
  mountUnit = "${utils.escapeSystemdPath disk.mountPoint}.mount";
in
{
  imports = [
    ./cachyos.nix
    ./openrgb.nix
  ];

  options.standalone = {
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "massive";
      description = "Static hostname for the standalone host.";
    };

    userName = lib.mkOption {
      type = lib.types.str;
      description = "User that owns the mounted data disk and the desktop session.";
    };

    userUid = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "UID of the standalone host's login account.";
    };

    userGid = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "GID of the standalone host's user-private primary group.";
    };

    homeDirectory = lib.mkOption {
      type = lib.types.str;
      description = "Home directory of the standalone host's login account.";
    };

    dataDisk = {
      enable = lib.mkEnableOption "the 970 EVO data disk";

      device = lib.mkOption {
        type = lib.types.str;
        default = "LABEL=970EVO";
        description = ''
          Device to mount. The ext4 label survives reconnects and keeps a UUID
          out of the module, matching the storage-label contract.
        '';
      };

      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/970";
        description = "Directory where the data disk is mounted.";
      };
    };
  };

  config = {
    nixpkgs.hostPlatform = "x86_64-linux";

    # CachyOS is an Arch derivative, and system-manager's pre-activation
    # assertion only accepts nixos, ubuntu and debian. It ships this option for
    # untested distributions, and everything this layer owns is
    # distribution-neutral: host data, systemd units, tmpfiles rules, and etc
    # files.
    system-manager.allowAnyDistro = true;

    # Daemon and CLI come from the same nixpkgs revision, so they cannot drift
    # apart the way a profile CLI and a distribution daemon did.
    environment.systemPackages = [ pkgs.tailscale ];

    # system-manager owns the account record on this host. userborn never
    # changes an existing UID and leaves supplementary groups alone because no
    # extraGroups are declared, so this only updates the primary group and the
    # shell of the account the CachyOS installer created.
    users.groups.${config.standalone.userName} = {
      gid = config.standalone.userGid;
    };

    users.users.${config.standalone.userName} = {
      isNormalUser = true;
      uid = config.standalone.userUid;
      group = config.standalone.userName;
      home = config.standalone.homeDirectory;
      createHome = false;
      shell = pkgs.nushell;
    };

    # pam_shells reads this file before it runs pam_unix, so a login shell that
    # is absent here fails authentication even with the correct password. The
    # NixOS hosts get the same list from environment.shells in
    # modules/aspects/mei.nix.
    environment.etc."shells" = {
      replaceExisting = true;
      text = ''
        # Managed by modules/standalone-linux/system.nix through system-manager.
        /bin/sh
        /bin/bash
        ${utils.toShellPath pkgs.nushell}
      '';
    };

    # Nix-built Noctalia links nixpkgs libpam, whose pam_unix calls
    # /run/wrappers/bin/unix_chkpwd. NixOS creates that wrapper through
    # security.pam; a foreign distribution does not. This is the same wrapper
    # definition NixOS uses, so lock screen password authentication reaches the
    # distribution's setuid helper.
    security.wrappers.unix_chkpwd = {
      source = "${pkgs.pam}/bin/unix_chkpwd";
      owner = "root";
      group = "root";
      setuid = true;
    };

    # Determinate Nix includes this file from /etc/nix/nix.conf, so daemon
    # settings can be declarative without taking over the installer's own file.
    # wheel gains trust, which lets a user-level nix.conf add substituters. The
    # cache union is repeated here so root and every user build from the same
    # signed caches.
    environment.etc."nix/nix.custom.conf" = {
      replaceExisting = true;
      text = ''
        # Managed by modules/standalone-linux/system.nix through system-manager.
        trusted-users = root @wheel
        extra-substituters = ${lib.concatStringsSep " " caches.substituters}
        extra-trusted-public-keys = ${lib.concatStringsSep " " caches.trustedPublicKeys}
      '';
    };

    # Both directories hold runtime and node-identity state rather than data
    # private to one unit, so activation creates them instead of tying their
    # lifetime to tailscaled. The paths are the ones the distribution package
    # used, so the node identity already on disk carries over without a second
    # login.
    systemd.tmpfiles.rules = [
      "d /var/lib/tailscale 0700 root root -"
      "d /run/tailscale 0755 root root -"
      "L+ /run/opengl-driver - - - - ${gpuDrivers}"
    ] ++ lib.optionals disk.enable [
      "d ${disk.mountPoint} 0755 root root -"
    ];

    systemd.mounts = lib.optional disk.enable {
      what = disk.device;
      where = disk.mountPoint;
      type = "ext4";
      options = "defaults";
      wantedBy = [ "multi-user.target" ];
    };

    # The filesystem root belongs to root when the disk comes from another
    # install, so the mount is not writable by the desktop user until ownership
    # moves. chown does not recurse, so existing files keep their owners.
    systemd.services.data-disk-ownership = lib.mkIf disk.enable {
      description = "Give ${config.standalone.userName} ownership of ${disk.mountPoint}";
      requires = [ mountUnit ];
      after = [ mountUnit ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathIsMountPoint = disk.mountPoint;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "data-disk-ownership" ''
          ${pkgs.coreutils}/bin/chown ${config.standalone.userName} ${disk.mountPoint}
          ${pkgs.coreutils}/bin/chmod 0755 ${disk.mountPoint}
        '';
      };
    };

    systemd.services.tailscaled = {
      description = "Tailscale node agent";
      documentation = [ "https://tailscale.com/kb/1017/install/" ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-pre.target" "systemd-resolved.service" ];
      after = [ "network-pre.target" "systemd-resolved.service" "set-hostname.service" ];
      unitConfig.ConditionPathExists = "/dev/net/tun";
      serviceConfig = {
        Type = "notify";
        ExecStartPre = "${pkgs.tailscale}/bin/tailscaled --cleanup";
        ExecStart = "${pkgs.tailscale}/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock";
        ExecStopPost = "${pkgs.tailscale}/bin/tailscaled --cleanup";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };

    # The static write is the only mechanism that sets the file, the kernel
    # hostname, and systemd-hostnamed together, so it is what runs here and it
    # is idempotent on later activations.
    #
    # Two nearby designs do not work on a foreign distribution. An
    # `environment.etc."hostname"` entry is ignored while a regular file already
    # sits at that path, because the engine replaces only files whose entry opts
    # into `replaceExisting`; and `hostnamectl set-hostname --transient` is
    # refused outright while a static hostname exists, which is the state this
    # machine is in.
    systemd.services.set-hostname = {
      description = "Set the static hostname to ${config.standalone.hostName}";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.systemd}/bin/hostnamectl set-hostname ${config.standalone.hostName}";
      };
    };
  };
}
