{ inputs, ... }:
{
  den.aspects.niri.nixos = import ../../nixos/niri.nix { inherit inputs; };
}
