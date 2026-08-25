{ inputs, ... }:
{
  den.aspects.storage.nixos.imports = [
    inputs.disko.nixosModules.disko
    ../../nixos/disk-config.nix
  ];
}
