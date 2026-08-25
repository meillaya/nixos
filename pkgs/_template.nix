# Template: wrap a prebuilt binary from a URL as a Nix derivation.
#
# Usage:
#   1. Copy this file to pkgs/<tool-name>.nix
#   2. Fill in pname, version, src url, and hash
#   3. Import it in the relevant package list:
#        (pkgs.callPackage ../../pkgs/<tool-name>.nix { })
#   4. Run: nix run .#home-switch
#
# To get the hash on first build, use a fake hash and nix will report the real one:
#   hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

{ stdenv, fetchzip, autoPatchelfHook, ... }:

stdenv.mkDerivation rec {
  pname = "example-tool";
  version = "1.0.0";

  src = fetchzip {
    url = "https://github.com/example/tool/releases/download/v${version}/tool_${version}_linux_amd64.tar.gz";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # autoPatchelfHook patches ELF binaries to find nix store libraries.
  # Remove for static binaries or scripts.
  nativeBuildInputs = [ autoPatchelfHook ];

  # Skip build phase for prebuilt binaries.
  dontBuild = true;

  installPhase = ''
    install -Dm755 example-tool $out/bin/example-tool
  '';

  meta = {
    description = "Example tool description";
    homepage = "https://github.com/example/tool";
    license = stdenv.lib.licenses.mit;
    platforms = stdenv.lib.platforms.linux;
  };
}
