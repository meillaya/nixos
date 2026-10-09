{ inputs, ... }:
{
  den.aspects.noctalia = {
    nixos = {
      imports = [ inputs.noctalia.nixosModules.default ];

      programs.noctalia = {
        enable = true;
        systemd.enable = true;
        recommendedServices.enable = true;
      };
    };

    homeManager = { config, ... }:
    let
      # Den projects user/home entity identity into this Home Manager option.
      home = config.home.homeDirectory;
      template = builtins.fromTOML (
        builtins.readFile ../standalone-linux/config/noctalia/config.toml
      );
      settings = template // {
        shell = template.shell // {
          avatar_path = "${home}/.face";
        };
        wallpaper = template.wallpaper // {
          directory = "${home}/Pictures/Wallpapers";
          default = template.wallpaper.default // {
            path = "${home}/Pictures/Wallpapers/wallhaven_e89l8k.jpg";
          };
        };
      };
    in
    {
      imports = [ inputs.noctalia.homeModules.default ];

      programs.noctalia = {
        enable = true;
        systemd.enable = true;
        validateConfig = true;
        inherit settings;
      };

      # Home Manager's sd-switch must leave the live desktop shell alone.
      systemd.user.services.noctalia.Unit.X-SwitchMethod = "keep-old";
    };
  };
}
