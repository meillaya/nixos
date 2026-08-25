{ den, ... }:
{
  den.aspects.darwin-platform.includes = [
    den.aspects.shared-policy
    den.aspects.darwin-base
    den.aspects.sops
    den.aspects.darwin-home
  ];
  # `preservation` is intentionally absent here — it is NixOS-flavored
  # (boot.initrd.systemd + services.preservation) and only wired in
  # ~/nixos/. The flake input is declared for lockfile symmetry.
}
