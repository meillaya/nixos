{ inputs }:
let
  lib = inputs.nixpkgs.lib;
  packageExceptions = builtins.fromJSON (builtins.readFile ../config/package-exceptions.json);
  allowedUnfreePackagesBySystem = builtins.listToAttrs (map
    (row: {
      name = "${row.system}:${row.pname}:${row.version}";
      value = true;
    })
    (packageExceptions.unfree or []));
  allowedUnfreePackagesByNameVersion = builtins.listToAttrs (map
    (row: {
      name = "${row.pname}:${row.version}";
      value = true;
    })
    (packageExceptions.unfree or []));
  packageSystem = pkg:
    if pkg ? stdenv && pkg.stdenv ? hostPlatform && pkg.stdenv.hostPlatform ? system then
      pkg.stdenv.hostPlatform.system
    else if pkg ? system then
      pkg.system
    else
      null;
  packageName = pkg: if pkg ? pname then pkg.pname else lib.getName pkg;
  packageVersion = pkg: if pkg ? version then pkg.version else lib.getVersion pkg;
  unfreeKeyFor = pkg: "${packageSystem pkg}:${packageName pkg}:${packageVersion pkg}";
  unfreeNameVersionKeyFor = pkg: "${packageName pkg}:${packageVersion pkg}";
  zixPins = builtins.fromJSON (builtins.readFile ../zix/managed/pins.json);
  # Ghostty 1.4.0 until nixpkgs carries it. On Linux, upstream's package
  # needs Zig 0.17, which this nixpkgs predates, so seed it from the ghostty
  # input's zig overlay and let upstream's own overlay build the package
  # against the shared nixpkgs. On Darwin, upstream's source package is not
  # supported, so override the signed DMG instead.
  ghosttyOverlay = final: prev:
    let
      upstream = inputs.ghostty;
      linux = prev.stdenv.hostPlatform.isLinux && inputs ? ghostty;
      darwin = prev.stdenv.hostPlatform.isDarwin && inputs ? ghostty;
    in
    lib.optionalAttrs darwin {
      ghostty-bin = lib.callPackageWith prev ../pkgs/ghostty-bin.nix { };
    } // lib.optionalAttrs linux {
      zig_0_17 = upstream.inputs.zig.packages.${prev.stdenv.hostPlatform.system}."0.17.0";
    } // lib.optionalAttrs linux (upstream.overlays.default final prev);
  # The emacs overlay always; the multiverse pin overlay when pins exist
  # (`zix add NAME@VERSION`). Pinning here rather than in a
  # module is deliberate: every host's package set comes from mkPkgs, and
  # this layer survives home-manager's useGlobalPkgs = true (which discards
  # per-HM nixpkgs definitions).
  overlays = [
    (import inputs.emacs-overlay)
    ghosttyOverlay
  ] ++ (
    if zixPins == { } || !(inputs ? multiverse) then [ ] else [
      (inputs.multiverse.lib.pinOverlay {
        pins = zixPins;
        config = { inherit (config) allowUnfreePredicate allowInsecure; };
      })
    ]
  );
  config = {
    allowUnfreePredicate = pkg:
      let
        system = packageSystem pkg;
        key = unfreeKeyFor pkg;
      in
        if system != null then
          builtins.hasAttr key allowedUnfreePackagesBySystem
        else
          builtins.hasAttr (unfreeNameVersionKeyFor pkg) allowedUnfreePackagesByNameVersion;
    allowInsecure = true;
  };
in
{
  inherit config overlays;
  mkPkgs = system: import inputs.nixpkgs { inherit system config overlays; };
}
