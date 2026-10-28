{ flake ? builtins.getFlake ("path:" + toString ../.) }:
let
  policy = import ../lib/nixpkgs.nix { inputs = flake.inputs; };
  policyConfig = policy.config;
  policyLinuxPkgs = policy.mkPkgs "x86_64-linux";
  nixos = flake.nixosConfigurations.remembrance.config;
  installed = flake.nixosConfigurations.installed.config;
  live = flake.nixosConfigurations.live.config;
  entropy = flake.darwinConfigurations.entropy.config;
  iso = flake.isoConfig.live.config;
  installedToplevel = flake.nixosConfigurations.installed.config.system.build.toplevel;
  packageName = package: package.pname or package.name or (builtins.baseNameOf (toString package));
  hasPackages = names: packages:
    let present = map packageName packages;
    in builtins.all (name: builtins.elem name present) names;
  tryDrvPath = package: builtins.tryEval package.drvPath;
in
assert builtins.attrNames flake.nixosConfigurations == [
  "antagony"
  "installed"
  "live"
  "remembrance"
];
assert builtins.attrNames (flake.darwinConfigurations or { }) == [ "entropy" ];
assert builtins.attrNames (flake.homeConfigurations or { }) == [ "massive" ];
assert builtins.attrNames (flake.systemConfigs or { }) == [ "massive" ];
assert flake.configurationEvaluationPaths == [
  "nixosConfigurations.remembrance"
  "nixosConfigurations.live"
  "nixosConfigurations.installed"
  "darwinConfigurations.entropy"
];
assert !(flake ? machineAuthority);
assert builtins.attrNames flake.iso == [ "live" ];
assert flake.iso ? live;
assert flake.isoConfig ? live;

# The installed system and the personal NixOS hosts share one storage
# contract: labels written by the installer, never a machine-specific disk ID.
assert installed.fileSystems."/".device == "/dev/disk/by-label/NIXROOT";
assert installed.fileSystems."/".fsType == "btrfs";
assert builtins.elem "subvol=@root" installed.fileSystems."/".options;
assert installed.fileSystems."/boot".device == "/dev/disk/by-label/NIXBOOT";
assert installed.fileSystems."/nix".neededForBoot;
assert nixos.fileSystems."/".device == "/dev/disk/by-label/NIXROOT";
assert nixos.fileSystems."/boot".device == "/dev/disk/by-label/NIXBOOT";
assert !(nixos ? nixConfig);
assert live.fileSystems."/".device == "tmpfs";

# Live and installed profiles.
assert installed.networking.hostName == "nixos";
assert installed.system.stateVersion == "26.05";
assert installed.users.mutableUsers;
assert installed.services.openssh.enable;
assert live.system.stateVersion == "26.05";
assert live.services.displayManager.autoLogin.user == "mei";
assert live.users.users.mei.initialHashedPassword == "";
assert !live.services.openssh.enable;
assert !live.boot.loader.systemd-boot.enable;
assert installed.boot.loader.systemd-boot.enable;

# ISO contract.
assert iso.isoImage.volumeID == "MEINIX_LIVE";
assert iso.isoImage.makeEfiBootable;
assert iso.isoImage.makeUsbBootable;
assert iso.system.nixos.variant_id == "live";
assert builtins.elem installedToplevel iso.isoImage.storeContents;
assert hasPackages [ "nixos-install-tui" ] iso.environment.systemPackages;

# Personal hosts keep their desktop and identity, but no enrollment values.
assert nixos.networking.hostName == "remembrance";
assert nixos.system.stateVersion == "21.05";
assert nixos.users.users.mei.uid == 1000;
assert nixos.users.users.mei.home == "/home/mei";
assert nixos.users.groups.users.gid == 100;
assert nixos.users.users.mei.isNormalUser;
assert nixos.programs.niri.enable;
assert nixos.services.displayManager.defaultSession == "niri";
assert nixos.programs.noctalia.enable;
assert nixos.hardware.enableRedistributableFirmware;
assert nixos.hardware.bluetooth.enable;
assert nixos.hardware.cpu.intel.updateMicrocode;
assert nixos.hardware.cpu.amd.updateMicrocode;
assert nixos.services.pipewire.enable;
assert nixos.services.power-profiles-daemon.enable;
assert nixos.services.upower.enable;
assert nixos.networking.networkmanager.enable;
assert hasPackages [ "ghostty" "obsidian" "noctalia" ] (
  nixos.home-manager.users.mei.home.packages ++ nixos.environment.systemPackages
);
assert packageName nixos.users.users.mei.shell == "nushell";
assert entropy.networking.hostName == "entropy";
assert entropy.users.users.mei.home == "/Users/mei";

# Package policy still resolves the requested unfree packages.
assert !(policyConfig ? allowBroken);
assert !(policyConfig ? permittedInsecurePackages);
assert !(policyConfig ? allowUnfree);
assert policyConfig.allowInsecure == true;
assert policyConfig ? allowUnfreePredicate;
assert (tryDrvPath policyLinuxPkgs.google-chrome).success;
assert (tryDrvPath policyLinuxPkgs.obsidian).success;
assert !(tryDrvPath policyLinuxPkgs.steam).success;

assert builtins.attrNames flake.apps.x86_64-linux == [
  "build"
  "build-switch"
  "clean"
  "home-news"
  "home-switch"
  "nh"
  "search-pkgs"
  "update"
  "zix"
];
assert builtins.attrNames (flake.apps.aarch64-darwin or { }) == [
  "build"
  "build-switch"
  "clean"
  "search-pkgs"
  "update"
  "zix"
];

"dendritic-config-eval=PASS"
