{ inputs }:
let
  lib = inputs.nixpkgs.lib;

  # Personal, name-only unfree policy. Version-exact exceptions make every
  # nixpkgs bump a policy edit and expire silently; the names below are what
  # this fleet actually asks for.
  unfreeNames = [
    "android-studio"
    "google-chrome"
    "idea"
    "obsidian"
    "postman"
    "pycharm"
    "raycast"
    "spotify"
    "terraform"
    "unrar"
    "vagrant"
  ];

  # macOS uses the signed DMG because upstream's source package is not
  # supported there. Linux takes the package from nixpkgs.
  ghosttyBinOverlay = _final: prev:
    lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
      ghostty-bin = lib.callPackageWith prev ../pkgs/ghostty-bin.nix { };
    };

  overlays = [ ghosttyBinOverlay ] ++ (
    let
      pins = builtins.fromJSON (builtins.readFile ../zix/managed/pins.json);
    in
    if pins == { } || !(inputs ? multiverse) then [ ] else [
      (inputs.multiverse.lib.pinOverlay {
        pins = pins;
        config = { inherit (config) allowUnfreePredicate allowInsecure; };
      })
    ]
  );

  config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) unfreeNames;
    allowInsecure = false;
  };
in
{
  inherit config overlays;
  mkPkgs = system: import inputs.nixpkgs { inherit system config overlays; };
}
