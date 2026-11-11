{
  description = "MeiNixOS live ISO and installer, built from the real workstation profile";

  inputs = {
    # Mirror the parent fleet pin. A path input does not carry its own lock into
    # the consumer, so the distro pins the same nixpkgs revision explicitly and
    # follows it through nixos-config.
    nixpkgs.url = "github:nixos/nixpkgs/f4a03c008967841f2a0b3cb7c436fc6fc31671f6";
    # The personal flake is the source of the real workstation profile. The
    # NixOS configuration below extends nixosConfigurations.remembrance rather
    # than duplicating a distro-only role chain.
    nixos-config = {
      url = "path:..";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixos-config, ... }:
    let
      system = "x86_64-linux";
      base = nixos-config.nixosConfigurations.remembrance;
      pkgs = base.pkgs;

      installed = base.extendModules {
        modules = [
          ./modules/base.nix
          ./modules/installed.nix
        ];
      };

      live = base.extendModules {
        modules = [
          ./modules/base.nix
          ./modules/live.nix
        ];
      };

      installerConfig = live.extendModules {
        modules = [
          ./modules/installer.nix
          {
            distro.installer.enable = true;
            distro.installer.installedSystem = "/run/not-used";
            distro.installer.flakeSource = "/run/not-used";
          }
        ];
      };

      installedToplevel = installed.config.system.build.toplevel;

      iso = live.extendModules {
        modules = [
          ./modules/iso.nix
          ./modules/installer.nix
          {
            distro.installer.enable = true;
            distro.installer.installedSystem = "${installedToplevel}";
            distro.installer.flakeSource = "${nixos-config}";
            environment.etc."nixos-config".source = nixos-config;
            isoImage.storeContents = [ installedToplevel ];
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        inherit installed live;
      };

      isoConfig.live = iso;
      iso.live = iso.config.system.build.isoImage;

      checks.${system} = {
        config-eval =
          assert (import ./tests/config-eval.nix {
            inherit self live installed iso;
          }) == "distro-config-eval=PASS";
          pkgs.runCommand "distro-config-eval" { } ''
            touch "$out"
          '';

        installer-disk-vm = import ./tests/installer-disk-vm.nix {
          inherit pkgs;
          liveConfig = installerConfig;
        };
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
