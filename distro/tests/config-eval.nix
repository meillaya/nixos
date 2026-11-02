{ self, live, installed, iso }:
let
  installedToplevel = installed.config.system.build.toplevel;
  packageName = package: package.pname or package.name or (builtins.baseNameOf (toString package));
  hasPackages = names: packages:
    let present = map packageName packages;
    in builtins.all (name: builtins.elem name present) names;
in
assert builtins.attrNames self.nixosConfigurations == [ "installed" "live" ];

# The distro is the real workstation profile, not a second role chain.
assert installed.programs.niri.enable;
assert installed.programs.noctalia.enable;
assert installed.services.displayManager.defaultSession == "niri";
assert installed.home-manager.users.mei.programs.nushell.enable;
assert hasPackages [ "obsidian" ] installed.home-manager.users.mei.home.packages;

# The installed system keeps the shared label contract.
assert installed.fileSystems."/".device == "/dev/disk/by-label/NIXROOT";
assert installed.fileSystems."/".fsType == "btrfs";
assert builtins.elem "subvol=@root" installed.fileSystems."/".options;
assert installed.fileSystems."/boot".device == "/dev/disk/by-label/NIXBOOT";
assert installed.fileSystems."/nix".neededForBoot;
assert installed.networking.hostName == "nixos";
assert installed.system.stateVersion == "26.05";
assert installed.users.mutableUsers;
assert installed.services.openssh.enable;

# The live profile uses the ISO medium, not the installed labels.
assert live.fileSystems."/".device == "tmpfs";
assert !(live.my.storage.labels.enable);
assert live.system.stateVersion == "26.05";
assert live.services.displayManager.autoLogin.user == "mei";
assert live.users.users.mei.initialHashedPassword == "";
assert !live.services.openssh.enable;
assert !live.boot.loader.systemd-boot.enable;

# ISO contract.
assert iso.isoImage.volumeID == "MEINIX_LIVE";
assert iso.isoImage.makeEfiBootable;
assert iso.isoImage.makeUsbBootable;
assert iso.system.nixos.variant_id == "live";
assert builtins.elem installedToplevel iso.isoImage.storeContents;
assert hasPackages [ "nixos-install-tui" ] iso.environment.systemPackages;

"distro-config-eval=PASS"
