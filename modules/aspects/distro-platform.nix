{ den, ... }:
{
  den.aspects.distro-platform.includes = [
    den.aspects.shared-policy
    den.aspects.nixos-base
    den.aspects.rootless-containers
    den.aspects.desktop-media
    den.aspects.stylix
    den.aspects.nix-direnv
    den.aspects.x86-hardware
  ];
}
