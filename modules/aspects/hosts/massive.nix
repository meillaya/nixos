{ den, inputs, ... }:
{
  den.aspects.massive-aarch64.includes = [ den.aspects.massive ];

  den.aspects.massive =
    { home, ... }:
    {
      includes = [
        den.aspects.mei
        den.aspects.rootless-containers
        den.aspects.noctalia
        den.aspects.desktop-media
      ];
      homeManager = import ../../standalone-linux/home-manager.nix {
        inherit inputs;
        inherit (home) userName homeDirectory;
      };
    };
}
