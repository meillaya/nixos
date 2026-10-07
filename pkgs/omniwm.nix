{ stdenvNoCC, lib, fetchzip }:

stdenvNoCC.mkDerivation {
  pname = "omniwm";
  version = "0.7.5";

  src = fetchzip {
    url = "https://github.com/OmniNull/OmniWM/releases/download/v0.7.5/OmniWM-v0.7.5.zip";
    hash = "sha256-cAX/bRu75mxhf0AOk9SGtEs3T0j9Pessm3y5/xKSk2E=";
  };

  dontBuild = true;

  # nix's fetchzip unpacks this zip as `Contents/` at the source root (the
  # OmniWM.app wrapper dir is an artifact of how system unzip/bsdtar read the
  # archive; nix's extraction is authoritative for the build). Anchor on
  # $src rather than relying on the installPhase cwd.
  installPhase = ''
    mkdir -p $out/Applications/OmniWM.app
    cp -r "$src"/Contents $out/Applications/OmniWM.app/
    mkdir -p $out/bin
    ln -s $out/Applications/OmniWM.app/Contents/MacOS/omniwmctl $out/bin/omniwmctl
  '';

  meta = {
    description = "Niri and Hyprland inspired tiling window manager for macOS";
    homepage = "https://github.com/OmniNull/OmniWM";
    license = lib.licenses.gpl2Only;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "omniwmctl";
  };
}
