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
        # The merged agent rules as one markdown file. The source of truth stays
        # agent-settings.nix; this output makes it buildable and gives the
        # agent-settings check a rendered artifact to inspect.
        agent-settings = pkgs.writeText "agent-settings.md"
          (import ../../agent-settings.nix).instructions;
      } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        # Chromium is the browser the CLI drives on Linux. Darwin uses a host
        # Chrome or Chromium through EXCALIDRAW_BROWSER_PATH.
        excalidraw-cli-browser = pkgs.callPackage ../../pkgs/excalidraw-cli {
          browser = "${pkgs.chromium}/bin/chromium";
        };
        # The SDDM theme system-manager installs for massive. The default Blush
        # preset is what the host selects; this output makes the theme
        # buildable and inspectable on its own.
        thyx = pkgs.callPackage ../../pkgs/thyx.nix { };
      };
    };
}
