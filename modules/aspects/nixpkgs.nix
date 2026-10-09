{ den, inputs, ... }:
let
  policy = import ../../lib/nixpkgs.nix { inherit inputs; };
  module = {
    nixpkgs = {
      inherit (policy) config overlays;
    };
  };
in
{
  den.aspects.shared-policy = {
    nixos = module;
    darwin = module;
  };
}
