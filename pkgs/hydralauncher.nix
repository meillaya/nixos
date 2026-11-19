# Hydra with host graphics and host umu-launcher.
#
# Hydra is an Electron AppImage. The nixpkgs package normally wraps it in
# buildFHSEnv, which hides the CachyOS /usr and makes the bundled game launch
# path use the Nix Mesa tree. That version skew is not acceptable for games, so
# this package runs the extracted AppImage directly on the host. The only patch
# is the umu-run helper: it execs the host umu-launcher so games use the host
# Vulkan driver and the same runtime as Steam and Heroic.
#
# The previous FHS package is kept in hydralauncher-fhs.nix for rollback.
#
# Version floor: nixpkgs nixos-unstable still packages Hydra 4.4.0, but 4.4.1 is
# the release that adds recompilation (PS4-port) and RPCS3 trophy achievements.
# Until the flake's nixpkgs pin carries 4.4.1 or newer, build the 4.4.1 AppImage
# from upstream. Once nixpkgs catches up this automatically returns to the
# nixpkgs package, so the floor can then be deleted.
{
  lib,
  appimageTools,
  fetchurl,
  hydralauncher,
  runCommand,
  makeWrapper,
}:

let
  inherit (hydralauncher) pname meta;

  fallbackVersion = "4.4.1";
  useFallback = lib.versionOlder hydralauncher.version fallbackVersion;

  fallbackSrc = fetchurl {
    url = "https://github.com/hydralauncher/hydra/releases/download/v${fallbackVersion}/hydralauncher-${fallbackVersion}.AppImage";
    hash = "sha256-zRy/rcz/1hP/JnnzwOQrP3M7DBEc3G8sd44QHu1XoKA=";
  };

  version = if useFallback then fallbackVersion else hydralauncher.version;
  contents =
    if useFallback then
      appimageTools.extract {
        inherit pname;
        src = fallbackSrc;
        version = fallbackVersion;
      }
    else
      hydralauncher.contents;

  patchedContents = runCommand "${pname}-${version}-host-patched" { } ''
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
runCommand "${pname}-${version}" {
  nativeBuildInputs = [ makeWrapper ];
  inherit pname version meta;
} ''
  mkdir -p $out/bin $out/share/hydralauncher
  cp -a ${patchedContents}/. $out/share/hydralauncher/
  chmod -R u+w $out/share/hydralauncher

  makeWrapper $out/share/hydralauncher/hydralauncher $out/bin/hydralauncher \
    --add-flags "--no-sandbox" \
    --unset LD_LIBRARY_PATH \
    --unset LD_PRELOAD \
    --prefix PATH : /usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

  install -Dm644 ${patchedContents}/hydralauncher.desktop \
    $out/share/applications/hydralauncher.desktop
  substituteInPlace $out/share/applications/hydralauncher.desktop \
    --replace-fail 'Exec=AppRun' "Exec=$out/bin/hydralauncher"

  install -Dm644 ${patchedContents}/usr/share/icons/hicolor/512x512/apps/hydralauncher.png \
    $out/share/icons/hicolor/512x512/apps/hydralauncher.png
''
