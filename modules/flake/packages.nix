{ inputs, ... }:
let
  mkConfiguredPkgs = (import ../../lib/nixpkgs.nix { inherit inputs; }).mkPkgs;
in
{
  perSystem = { system, ... }:
    let
      pkgs = mkConfiguredPkgs system;
      lib = pkgs.lib;
    in
    {
      packages = {
        zix = pkgs.callPackage ../../tools/zix/package.nix { };
        excalidraw-cli = pkgs.callPackage ../../pkgs/excalidraw-cli { };
      } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        # Chromium is the browser the CLI drives on Linux. Darwin uses a host
        # Chrome or Chromium through EXCALIDRAW_BROWSER_PATH.
        excalidraw-cli-browser = pkgs.callPackage ../../pkgs/excalidraw-cli {
          browser = "${pkgs.chromium}/bin/chromium";
        };
      };
    };
}
