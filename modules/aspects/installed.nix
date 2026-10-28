{ den, ... }:
{
  den.aspects.installed = {
    includes = [
      den.aspects.distro-role
      den.aspects.storage-labels
    ];
    nixos.imports = [
      ../distro/base.nix
      ../distro/installed.nix
    ];
  };
}
