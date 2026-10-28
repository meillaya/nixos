{ den, ... }:
{
  den.aspects.live = {
    includes = [ den.aspects.distro-role ];
    nixos.imports = [
      ../distro/base.nix
      ../distro/live.nix
    ];
  };
}
