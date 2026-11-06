# Hydralauncher with the game tools and a current umu-run in its FHS
# environment.
#
# The nixpkgs Hydra is an AppImage wrapped in buildFHSEnv, so Hydra sees its
# own /usr/bin instead of CachyOS. That hides winetricks and mangohud, and
# gamemoderun may be absent from the host. The bundled umu-run 1.3.0 also fails
# to install the Steam runtime with a digest mismatch.
#
# This package inherits the Hydra version, extracted contents, install commands,
# metadata, and source from nixpkgs, then patches only what the FHS isolation
# needs. A nixpkgs bump therefore moves Hydra and this wrapper together; only a
# change to the AppImage's resources layout or its compatibility checks would
# need a follow-up edit.
{
  hydralauncher,
  appimageTools,
  runCommand,
  winetricks,
  mangohud,
  gamemode,
  umu-launcher-unwrapped,
}:

let
  inherit (hydralauncher) pname version contents;

  patchedContents = runCommand "${pname}-${version}-patched" { } ''
    cp -a ${contents} $out
    chmod -R u+w $out

    cat > $out/resources/umu-run <<'EOF'
    #!/usr/bin/env python3
    import os
    import sys

    os.execv("/usr/bin/umu-run", ["umu-run", *sys.argv[1:]])
    EOF
    chmod 0755 $out/resources/umu-run
  '';
in
appimageTools.wrapAppImage {
  inherit pname version;
  contents = patchedContents;

  extraPkgs = pkgs: [
    pkgs.python3
    umu-launcher-unwrapped
    winetricks
    mangohud
    gamemode
  ];

  extraInstallCommands = hydralauncher.extraInstallCommands;
  meta = hydralauncher.meta;
}
