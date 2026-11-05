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

      # The merged agent rules must stay renderable and complete. A missing
      # section means agent-settings.nix was truncated or an include was
      # dropped, which nothing else would catch.
      agent-settings =
        let
          settings = import ../../agent-settings.nix;
          requiredSections = [
            "## This repo"
            "## Environment"
            "## Before you call it done"
            "## Secrets"
            "## Code style"
            "## Tests"
            "## Commit messages"
            "## Tone"
            "## Writing style: no LLM tells"
            "## How to write well"
            "## Drawing diagrams with the Excalidraw CLI"
          ];
          missingSections = builtins.filter
            (section: !(pkgs.lib.hasInfix section settings.instructions))
            requiredSections;
        in
        if missingSections != [ ] then
          throw "agent-settings: missing sections: ${builtins.concatStringsSep ", " missingSections}"
        else
          pkgs.runCommand "agent-settings" { } ''
            test -s ${pkgs.writeText "agent-settings.md" settings.instructions}
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
    } // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      # The standalone host boots this theme from the Nix profile, so the
      # package must keep the Blush preset selected and carry the QML, image,
      # and font files SDDM and fontconfig read.
      thyx-theme =
        let
          thyx = pkgs.callPackage ../../pkgs/thyx.nix { };
        in
        pkgs.runCommand "thyx-theme" {
          nativeBuildInputs = [ pkgs.gnugrep ];
        } ''
          test -f ${thyx}/share/sddm/themes/thyx/src/Main.qml
          test -f ${thyx}/share/sddm/themes/thyx/backgrounds/blush.jpg
          grep -q '^Background="backgrounds/blush.jpg"$' ${thyx}/share/sddm/themes/thyx/theme.conf
          test -f ${thyx}/share/fonts/truetype/thyx/PlusJakartaSans-VariableFont_wght.ttf
          touch "$out"
        '';
    };
  };
}
