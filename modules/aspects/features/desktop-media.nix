{ den, inputs, ... }:
{
  den.aspects.desktop-media = {
    nixos =
      { lib, pkgs, ... }:
      let
        system = pkgs.stdenv.hostPlatform.system;
        supported = system == "x86_64-linux";
        # Font-wrapped Helium lives in pkgs/helium.nix (package-policy keeps
        # inline derivation recipes out of production modules).
        helium = pkgs.callPackage ../../../pkgs/helium.nix {
          helium = inputs.helium.packages.${system}.default;
        };
      in
      {
        imports = [ inputs.spicetify-nix.nixosModules.spicetify ];

        config = lib.mkIf supported {
          programs.spicetify.enable = true;

          environment.systemPackages = [ helium ];
        };
      };

    homeManager =
      { lib, pkgs, ... }:
      let
        system = pkgs.stdenv.hostPlatform.system;
        supported = system == "x86_64-linux";
        helium = pkgs.callPackage ../../../pkgs/helium.nix {
          helium = inputs.helium.packages.${system}.default;
        };
      in
      {
        # Module imports are static; support is gated in config below so module
        # argument resolution cannot recurse through pkgs during import loading.
        imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

        config = lib.mkIf supported {
          # Spicetify provides the wrapped Spotify package; do not also install
          # pkgs.spotify because both packages expose the same executables.
          programs.spicetify.enable = true;

          home.packages = [ helium ];
        };
      };
  };
}
