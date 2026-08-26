# Auto-enrollment tooling carried by the per-host installer ISO.
#
# Bundles the hardware-intake Python scripts (probe + collector + intake) and a
# thin launcher so the booted installer can run `nix-config-hardware-auto-enroll`
# to probe the real target hardware and emit the reviewed declaration + RFC-6902
# intake document under /root/enroll. See `scripts/hardware/auto_enroll.py`.
{ stdenv, python3, pciutils, mesa-demos, lib }:
stdenv.mkDerivation {
  pname = "nix-config-hardware-enrollment";
  version = "1.0.0";
  src = lib.cleanSourceWith {
    src = ../scripts;
    filter = name: type:
      (lib.hasPrefix (toString ../scripts + "/hardware") name)
      || (lib.hasPrefix (toString ../scripts + "/support") name);
  };
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/python/hardware $out/lib/python/support $out/bin
    cp -r hardware/* $out/lib/python/hardware/
    cp -r support/* $out/lib/python/support/
    cat > $out/bin/nix-config-hardware-auto-enroll <<EOF
    #!/usr/bin/env bash
    set -euo pipefail
    export PYTHONPATH=$out/lib/python
    exec ${python3}/bin/python $out/lib/python/hardware/auto_enroll.py "\$@"
    EOF
    chmod +x $out/bin/nix-config-hardware-auto-enroll
    runHook postInstall
  '';
  propagatedBuildInputs = [ pciutils mesa-demos ];
  meta.description = "ISO auto-enrollment tooling (hardware probe + intake writer)";
}
