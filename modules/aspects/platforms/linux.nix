{ den, ... }:
{
  den.aspects.linux-platform.includes = [
    den.aspects.shared-policy
    den.aspects.nixos-base
    den.aspects.sops
    den.aspects.desktop-media
    den.aspects.preservation
    den.aspects.stylix
    den.aspects.nix-direnv
  ];
}
