# zix as a self-contained program.
#
# zix reads the configuration it manages at runtime: the nearest zix.json from
# the caller's directory, or --repo, or a system manifest at /etc/zix. This
# derivation therefore ships code only and records no repository path, which is
# what lets one package serve any configuration.
{
  lib,
  stdenv,
  python3,
  makeWrapper,
}:

let
  # cli.py owns the version, so `zix --version` and the package cannot drift.
  versionLine = lib.findFirst (lib.hasPrefix "VERSION = ") null (
    lib.splitString "\n" (builtins.readFile ./cli.py)
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "zix";
  version =
    if versionLine == null then
      throw "tools/zix/cli.py must define VERSION = \"x.y.z\""
    else
      lib.removeSuffix "\"" (lib.removePrefix "VERSION = \"" versionLine);

  # Only the code that runs. tests/, the flake and the package expression are
  # build-time concerns and stay out of the store path.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./cli.py
      ./zixlib
    ];
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/zix $out/bin
    cp cli.py $out/share/zix/
    cp -r zixlib $out/share/zix/

    # Running cli.py as a file puts its directory on sys.path, so `zixlib` is
    # importable without PYTHONPATH.
    makeWrapper ${python3}/bin/python3 $out/bin/zix \
      --add-flags "$out/share/zix/cli.py"

    runHook postInstall
  '';

  meta = {
    description = "Idempotent manager for Nix configurations: packages, pins, sandboxes and VMs";
    homepage = "https://github.com/meillaya/nixos/tree/main/tools/zix";
    mainProgram = "zix";
    platforms = lib.platforms.unix;
    # No license is declared here because the tree carries none; the parent
    # repository has no LICENSE file either. Add one before distributing.
  };
})
