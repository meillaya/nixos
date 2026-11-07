{
  self,
  live,
  installed,
  iso,
}:
let
  installedToplevel = installed.config.system.build.toplevel;
  packageName = package: package.pname or package.name or (builtins.baseNameOf (toString package));
  hasPackages =
    names: packages:
    let
      present = map packageName packages;
    in
    builtins.all (name: builtins.elem name present) names;
in
assert
  builtins.attrNames self.nixosConfigurations == [
    "installed"
    "live"
  ];

# The installed profile is the real workstation configuration, including the
# host identity and the personal system services. This is what makes the first
# boot the named host instead of a neutral install.
assert installed.config.programs.niri.enable;
assert installed.config.programs.noctalia.enable;
assert installed.config.services.displayManager.defaultSession == "niri";
assert installed.config.home-manager.users.mei.programs.nushell.enable;
assert hasPackages [ "obsidian" ] installed.config.home-manager.users.mei.home.packages;

# The installed system keeps the shared label contract.
assert installed.config.fileSystems."/".device == "/dev/disk/by-label/NIXROOT";
assert installed.config.fileSystems."/".fsType == "btrfs";
assert builtins.elem "subvol=@root" installed.config.fileSystems."/".options;
assert installed.config.fileSystems."/boot".device == "/dev/disk/by-label/NIXBOOT";
assert installed.config.fileSystems."/nix".neededForBoot;
assert installed.config.networking.hostName == "remembrance";
assert installed.config.system.stateVersion == "21.05";
assert installed.config.time.timeZone == "America/New_York";
assert installed.config.services.tailscale.enable;
assert installed.config.services.syncthing.enable;
assert installed.config.users.users.mei.openssh.authorizedKeys.keys != [ ];
assert installed.config.users.mutableUsers;
assert installed.config.services.openssh.enable;

# The live profile keeps the personal configuration off the medium.
assert live.config.fileSystems."/".device == "tmpfs";
assert !(live.config.my.storage.labels.enable);
assert live.config.networking.hostName == "meinix-live";
assert live.config.system.stateVersion == "21.05";
assert live.config.time.timeZone == "UTC";
assert live.config.i18n.defaultLocale == "en_US.UTF-8";
assert live.config.console.keyMap == "us";
assert !live.config.services.tailscale.enable;
assert !live.config.services.syncthing.enable;
assert live.config.users.users.mei.openssh.authorizedKeys.keys == [ ];
assert live.config.users.users.root.openssh.authorizedKeys.keys == [ ];
assert live.config.services.displayManager.autoLogin.user == "mei";
assert live.config.users.users.mei.initialHashedPassword == "";
assert !live.config.services.openssh.enable;
assert !live.config.boot.loader.systemd-boot.enable;

# ISO contract.
assert iso.config.isoImage.volumeID == "MEINIX_LIVE";
assert iso.config.isoImage.makeEfiBootable;
assert iso.config.isoImage.makeUsbBootable;
assert iso.config.system.nixos.variant_id == "live";
assert builtins.elem installedToplevel iso.config.isoImage.storeContents;
assert hasPackages [
  "nixos-install-tui"
  "nixos-install-gui"
] iso.config.environment.systemPackages;
assert iso.lib.hasInfix "spawn-at-startup \"nixos-install-gui\""
  iso.config.home-manager.users.mei.home.file.".config/niri/config.kdl".text;

"distro-config-eval=PASS"
