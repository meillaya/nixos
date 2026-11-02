{ den, ... }:
{
  den.aspects.linux-platform.includes = [
    den.aspects.shared-policy
    den.aspects.nixos-base
    den.aspects.rootless-containers
    den.aspects.sops
    den.aspects.desktop-media
    den.aspects.x86-hardware
  ];
}
