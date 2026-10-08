{
  description = "zix - idempotent manager for Nix configurations";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (system: pkgs: rec {
        zix = pkgs.callPackage ./package.nix { };
        default = zix;
      });

      apps = forAllSystems (system: pkgs: {
        default = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${system}.zix;
        };
        zix = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${system}.zix;
        };
      });

      # The suite shadows every nix binary with a stub, so it runs with no
      # network. Two GetTests cases probe a real `nix profile add --help`
      # instead, which is why nix itself is on PATH here.
      checks = forAllSystems (system: pkgs: {
        zix-tests = pkgs.runCommand "zix-tests" {
          nativeBuildInputs = [
            pkgs.python3
            pkgs.nix
          ];
        } ''
          mkdir work
          cp -r ${self}/cli.py ${self}/zixlib ${self}/tests work/
          cd work
          python3 -m unittest discover -s tests -v >&2
          touch $out
        '';
      });
    };
}
