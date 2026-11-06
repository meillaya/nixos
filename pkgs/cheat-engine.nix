{ lib, stdenv, fetchurl, unzip }:

stdenv.mkDerivation {
  pname = "cheat-engine";
  version = "7.7.1";

  src = fetchurl {
    url = "https://cheatengine.org/download/CheatEngineLinux771.zip";
    hash = "sha256-D7DZBDroVqzeA7W4caLzYn689nSurNBF+G1W2RoH8Xc=";
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    unzip $src -d source
  '';
  sourceRoot = "source";

  installPhase = ''
    mkdir -p $out/share/cheat-engine $out/bin
    cp -a . $out/share/cheat-engine
    chmod -R u+w $out/share/cheat-engine

    cat > $out/bin/cheat-engine <<EOF
    #!/bin/sh
    set -eu
    dir="$out/share/cheat-engine"
    cd "\$dir"
    unset LD_LIBRARY_PATH
    export LD_LIBRARY_PATH="\$dir"
    exec "\$dir/cheatengine-x86_64" "\$@"
    EOF
    chmod 0755 $out/bin/cheat-engine
  '';

  meta = {
    description = "Cheat Engine, Linux build";
    homepage = "https://cheatengine.org/";
    license = lib.licenses.gpl2Plus;
    mainProgram = "cheat-engine";
    platforms = [ "x86_64-linux" ];
  };
}
