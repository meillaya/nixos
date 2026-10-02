{ inputs, ... }:
{
  perSystem = { system, ... }:
    let pkgs = inputs.nixpkgs.legacyPackages.${system};
    in {
      devShells.default = with pkgs; mkShell {
        nativeBuildInputs = [ bashInteractive git python3 ];
        shellHook = ''
          export EDITOR=vim
          # Run the working-tree zix when in the repo, else the flake's copy.
          zix() {
            local cli="$PWD/tools/zix/cli.py"
            [ -f "$cli" ] || cli="${inputs.self}/tools/zix/cli.py"
            python3 "$cli" "$@"
          }
        '';
      };
    };
}
