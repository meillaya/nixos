{ inputs, lib, ... }:
{
  perSystem = { pkgs, system, ... }: {
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

      install-staging = pkgs.runCommand "install-staging" {
        nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.nix pkgs.python3 ];
        NIX_CONFIG = "experimental-features = nix-command flakes";
        src = inputs.self;
      } ''
        cp -R "$src" source
        chmod -R u+w source
        bash source/tests/install-staging.sh
        touch "$out"
      '';

      package-policy = pkgs.runCommand "package-policy" {
        nativeBuildInputs = [ pkgs.bash pkgs.gnugrep pkgs.nix pkgs.python3 ];
        DENDRITIC_POLICY_REPO_ROOT = "${inputs.self}";
        DENDRITIC_NIXPKGS_FLAKE = "${inputs.nixpkgs}";
        DENDRITIC_EMACS_OVERLAY_FLAKE = "${inputs.emacs-overlay}";
        src = inputs.self;
      } ''
        cp -R "$src" source
        chmod -R u+w source
        bash source/tests/package-policy.sh
        touch "$out"
      '';

      dendritic-config-eval =
        assert (import ../../tests/dendritic-config-eval.nix { flake = inputs.self; })
          == "dendritic-config-eval=PASS";
        pkgs.runCommand "dendritic-config-eval" { } ''
          touch "$out"
        '';

      bootstrap-password-mutations = pkgs.runCommand "bootstrap-password-mutations" {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gnused
          pkgs.gnutar
          pkgs.jq
          pkgs.nix
        ];
        NIX_CONFIG = "experimental-features = nix-command flakes";
        src = inputs.self;
      } ''
        cp -R "$src" source
        chmod -R u+w source
        bash source/tests/bootstrap-password-mutations.sh
        touch "$out"
      '';

      dendritic-shells = pkgs.runCommand "dendritic-shells" {
        nativeBuildInputs = [ pkgs.bash ];
        DENDRITIC_NU_BIN = "${pkgs.nushell}/bin/nu";
        DENDRITIC_BASH_BIN = "${pkgs.bashInteractive}/bin/bash";
        DENDRITIC_ZSH_BIN = "${pkgs.zsh}/bin/zsh";
        DENDRITIC_FISH_BIN = "${pkgs.fish}/bin/fish";
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
    } // lib.optionalAttrs (system == "x86_64-linux") {
      # Gate-inertness VM (plan todo 14): boots the ISO's extended config
      # (`flake.isoConfig.antagony`, the very config `flake.iso` builds from)
      # as a QEMU test machine in one run with both variants — a plain boot
      # (the unit must stay inactive) and a test-only `nixos.autoinstall=1`
      # boot (the unit runs, refuses safely, and the rescue target takes
      # over). The ISO hosts are x86_64-linux only, so the check exists only
      # for that system.
      iso-autostart-vm = import ../../tests/iso-autostart-vm.nix {
        inherit pkgs;
        isoConfig = inputs.self.isoConfig.antagony;
      };
    };
  };
}
