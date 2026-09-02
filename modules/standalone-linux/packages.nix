{ pkgs, inputs }:

let
  shared-packages = import ../shared/packages.nix {
    inherit pkgs;
  };
  linux-packages = import ../linux/packages.nix {
    inherit pkgs;
  };
in
shared-packages ++ linux-packages ++ [
  pkgs.sops
]
