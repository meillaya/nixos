{ inputs }:
let
  lib = inputs.nixpkgs.lib;

  # Personal, name-only unfree policy. Version-exact exceptions make every
  # nixpkgs bump a policy edit and expire silently; the names below are what
  # this fleet actually asks for.
  unfreeNames = [
    "android-studio"
    "google-chrome"
    "intellij-idea"
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

  # The nixpkgs cargo setup hook now runs every Rust build through
  # cargoUseSystemLibs, which forces system libraries for zstd-sys, aws-lc-sys,
  # libgit2-sys, libsqlite3-sys, libssh2-sys, and libz-sys. The nixpkgs packages
  # below omit some of those inputs, so add them here. Drop an entry when the
  # nixpkgs package carries the inputs itself.
  rustSystemLibsOverlay = final: prev: {
    fnm = prev.fnm.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.pkg-config ];
      buildInputs = (old.buildInputs or [ ]) ++ [ final.zstd ];
    });

    tectonic-unwrapped = prev.tectonic-unwrapped.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ final.aws-lc ];
    });

    yaak = prev.yaak.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [
        final.aws-lc
        final.libgit2
        final.libssh2
        final.sqlite
        final.zlib
        final.zstd
      ];
    });
  };

  overlays = [ ghosttyBinOverlay rustSystemLibsOverlay ] ++ (
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
    # glances (modules/shared/packages.nix) propagates python-jose for its web
    # UI. The 2026-11-11 nixpkgs marked python-jose 3.5.0 insecure
    # (CVE-2026-120459) and evaluation of every host aborted. Narrow,
    # version-exact exception until nixpkgs ships a fixed python-jose or
    # glances drops the dependency; delete this entry then.
    permittedInsecurePackages = [ "python3.14-python-jose-3.5.0" ];
  };
in
{
  inherit config overlays;
  mkPkgs = system: import inputs.nixpkgs { inherit system config overlays; };
}
