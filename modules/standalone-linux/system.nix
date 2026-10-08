{ pkgs, ... }:

# System-level layer for the `massive` standalone host, built into
# `systemConfigs.massive` by modules/flake/system-manager.nix.
#
# This file owns only what Home Manager cannot reach on a non-NixOS machine:
# the static hostname and the tailscaled service. The desktop, every user
# package, and the rest of the system state stay with ./home-manager.nix and the
# CachyOS package manager.
{
  nixpkgs.hostPlatform = "x86_64-linux";

  # CachyOS is an Arch derivative, and system-manager's pre-activation assertion
  # only accepts nixos, ubuntu and debian. It ships this option for untested
  # distributions, and everything this layer owns is distribution-neutral:
  # a hostname, systemd units, and tmpfiles rules.
  system-manager.allowAnyDistro = true;

  # Daemon and CLI come from the same nixpkgs revision, so they cannot drift
  # apart the way a profile CLI and a distribution daemon did.
  environment.systemPackages = [ pkgs.tailscale ];

  # Both directories hold runtime and node-identity state rather than data
  # private to one unit, so activation creates them instead of tying their
  # lifetime to tailscaled. The paths are the ones the distribution package
  # used, so the node identity already on disk carries over without a second
  # login.
  systemd.tmpfiles.rules = [
    "d /var/lib/tailscale 0700 root root -"
    "d /run/tailscale 0755 root root -"
  ];

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
  # hostname, and systemd-hostnamed together, so it is what runs here and it is
  # idempotent on later activations.
  #
  # Two nearby designs do not work on a foreign distribution. An
  # `environment.etc."hostname"` entry is ignored while a regular file already
  # sits at that path, because the engine replaces only files whose entry opts
  # into `replaceExisting`; and `hostnamectl set-hostname --transient` is
  # refused outright while a static hostname exists, which is the state this
  # machine is in.
  systemd.services.set-hostname = {
    description = "Set the static hostname to massive";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.systemd}/bin/hostnamectl set-hostname massive";
    };
  };
}
