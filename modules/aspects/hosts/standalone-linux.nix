{ den, inputs, ... }:
{
  den.aspects.standalone-linux-aarch64.includes = [ den.aspects.standalone-linux ];

  den.aspects.standalone-linux =
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
