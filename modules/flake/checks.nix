{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    checks = {
      dendritic-architecture = pkgs.runCommand "dendritic-architecture" {
        nativeBuildInputs = [ pkgs.bash pkgs.fastfetch pkgs.gnugrep pkgs.python3 ];
        DENDRITIC_DARWIN_CONFIGURATION_SYSTEMS =
          builtins.toJSON (builtins.attrNames (inputs.self.darwinConfigurations or { }));
        src = inputs.self;
      } ''
        cp -R "$src" source
        chmod -R u+w source
        bash source/tests/dendritic-architecture.sh
        touch "$out"
      '';

      dendritic-boundaries = pkgs.runCommand "dendritic-boundaries" {
        nativeBuildInputs = [ pkgs.bash pkgs.gnugrep ];
        src = inputs.self;
      } ''
        cp -R "$src" source
        chmod -R u+w source
        bash source/tests/dendritic-boundaries.sh
        touch "$out"
      '';

      dendritic-apps = pkgs.runCommand "dendritic-apps" {
        nativeBuildInputs = [ pkgs.bash pkgs.gawk pkgs.nix pkgs.python3 ];
        NIX_CONFIG = "experimental-features = nix-command flakes";
        src = inputs.self;
      } ''
        cp -R "$src" source
        chmod -R u+w source
        bash source/tests/dendritic-apps.sh
        touch "$out"
      '';

      script-args = pkgs.runCommand "script-args" {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.gnugrep
          pkgs.inetutils
        ];
        src = inputs.self;
      } ''
        cp -R "$src" source
        chmod -R u+w source
        bash source/tests/script-args.sh
        touch "$out"
      '';

      dendritic-config-eval =
        assert (import ../../tests/dendritic-config-eval.nix { flake = inputs.self; })
          == "dendritic-config-eval=PASS";
        pkgs.runCommand "dendritic-config-eval" { } ''
          touch "$out"
        '';

      dendritic-shells = pkgs.runCommand "dendritic-shells" {
        nativeBuildInputs = [ pkgs.bash ];
        DENDRITIC_NU_BIN = "${pkgs.nushell}/bin/nu";
        DENDRITIC_BASH_BIN = "${pkgs.bashInteractive}/bin/bash";
        src = inputs.self;
      } ''
        bash "$src/tests/dendritic-shells.sh"
        touch "$out"
      '';

      zix = pkgs.runCommand "zix" {
        nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.diffutils pkgs.gnugrep pkgs.nix pkgs.python3 ];
        src = inputs.self;
      } ''
        cp -R "$src" source
        chmod -R u+w source
        bash source/tests/zix.sh
        touch "$out"
      '';

      prose = pkgs.runCommand "prose" {
        nativeBuildInputs = [ pkgs.bash pkgs.python3 ];
        src = inputs.self;
      } ''
        cp -R "$src" source
        chmod -R u+w source
        bash source/tests/prose.sh
        touch "$out"
      '';
    };
  };
}
