{ inputs, ... }:
{
  den.aspects.stylix = {
    nixos = { pkgs, lib, ... }: {
      imports = [ inputs.stylix.nixosModules.stylix ];

      # Default to no-op (no palette chosen) so the module evaluates
      # cleanly. Pick a real base16 / catppuccin / gruvbox palette and a
      # font in `stylix.targets.<host>.colors` / `.fonts` per host before
      # activation. See https://stylix.andersevenrud.dev for options.
      stylix.enable = false;
    };
  };
}
