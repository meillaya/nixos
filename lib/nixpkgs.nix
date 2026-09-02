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
  overlays = [ (import inputs.emacs-overlay) ];
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
