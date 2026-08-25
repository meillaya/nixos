{
  den.aspects.linux-desktop = {
    nixos.home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "before-home-manager";
    };
    provides.to-users.homeManager = import ../../nixos/home-manager.nix;
  };
}
