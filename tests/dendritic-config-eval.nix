{ flake ? builtins.getFlake ("path:" + toString ../.) }:
let
  policy = import ../lib/nixpkgs.nix { inputs = flake.inputs; };
  policyConfig = policy.config;
  policyLinuxPkgs = policy.mkPkgs "x86_64-linux";
  nixos = flake.nixosConfigurations.remembrance.config;
  entropy = flake.darwinConfigurations.entropy.config;
  massive = flake.homeConfigurations.massive.config;
  system = flake.systemConfigs.massive.config;
  lib = flake.inputs.nixpkgs.lib;
  packageName = package: package.pname or package.name or (builtins.baseNameOf (toString package));
  hasPackages = names: packages:
    let present = map packageName packages;
    in builtins.all (name: builtins.elem name present) names;
  tryDrvPath = package: builtins.tryEval package.drvPath;
in
assert builtins.attrNames flake.nixosConfigurations == [
  "antagony"
  "remembrance"
];
assert builtins.attrNames (flake.darwinConfigurations or { }) == [ "entropy" ];
assert builtins.attrNames (flake.homeConfigurations or { }) == [ "massive" ];
assert builtins.attrNames (flake.systemConfigs or { }) == [ "massive" ];
assert !(flake ? machineAuthority);
assert !(flake ? iso);
assert !(flake ? isoConfig);

# The personal NixOS hosts use the shared label contract.
assert nixos.fileSystems."/".device == "/dev/disk/by-label/NIXROOT";
assert nixos.fileSystems."/".fsType == "btrfs";
assert builtins.elem "subvol=@root" nixos.fileSystems."/".options;
assert nixos.fileSystems."/boot".device == "/dev/disk/by-label/NIXBOOT";
assert nixos.fileSystems."/nix".neededForBoot;
assert !(nixos ? nixConfig);

# Personal hosts keep their desktop and identity, but no enrollment values.
assert nixos.networking.hostName == "remembrance";
assert nixos.system.stateVersion == "21.05";
assert nixos.users.users.mei.uid == 1000;
assert nixos.users.users.mei.home == "/home/mei";
assert nixos.users.groups.users.gid == 100;
assert nixos.users.users.mei.isNormalUser;
assert nixos.programs.niri.enable;
assert nixos.services.greetd.enable;
assert nixos.services.displayManager.noctalia-greeter.enable;
assert nixos.services.displayManager.noctalia-greeter.settings.session.default == "Niri";
assert !(nixos.services.xserver.displayManager.lightdm.enable);
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
# The shared Home Manager payload applies to the NixOS hosts too.
assert nixos.home-manager.users.mei.home.activation ? fixSshConfigPermissions;
# The NixOS hosts already provide the PAM helper wrapper that Nix-built
# Noctalia expects. The standalone layer mirrors the same wrapper.
assert nixos.security.wrappers.unix_chkpwd.setuid;
assert entropy.networking.hostName == "entropy";
assert entropy.users.users.mei.home == "/Users/mei";

# The standalone host keeps its own Home Manager and system-manager layers.
assert massive.home.username == "mei";
assert massive.home.homeDirectory == "/home/mei";
assert massive.programs.nushell.enable;

# `programs.ssh` links ~/.ssh/config from the store, where a user namespace
# reads the owner as `nobody` and OpenSSH rejects the file. Activation replaces
# the link with a 0600 copy.
assert massive.home.file.".ssh/config".force;
assert lib.hasInfix "install -m 0600" massive.home.activation.fixSshConfigPermissions.data;
assert builtins.hasAttr "podman" massive.systemd.user.sockets;
assert builtins.isAttrs flake.systemConfigs.massive;

# system-manager owns the non-NixOS desktop plumbing: the GPU driver tree, the
# Nix settings the distribution's nix.conf includes, and the data disk mount.
assert massive.targets.genericLinux.enable;
assert !massive.targets.genericLinux.gpu.enable;
assert !(massive.xdg.configFile ? "nix/nix.conf");
assert lib.hasInfix "trusted-users = root @wheel" system.environment.etc."nix/nix.custom.conf".text;
assert lib.any (rule: lib.hasInfix "/run/opengl-driver" rule) system.systemd.tmpfiles.rules;
assert lib.any (rule: lib.hasInfix "amdgpu-coredump" rule) system.systemd.tmpfiles.rules;
assert builtins.hasAttr "amdgpu-coredump" system.systemd.services;
assert lib.hasInfix "Relogin=true" system.environment.etc."sddm.conf.d/10-gaming-autologin.conf".text;
assert lib.hasInfix "Storage=persistent" system.environment.etc."systemd/journald.conf.d/99-gaming.conf".text;
assert lib.hasInfix "kernel.yama.ptrace_scope = 0" system.environment.etc."sysctl.d/99-gaming-ptrace.conf".text;
assert lib.any (mount: mount.where == "/mnt/970" && mount.what == "LABEL=970EVO") system.systemd.mounts;
assert builtins.hasAttr "data-disk-ownership" system.systemd.services;

# The standalone host declares its login account, shell list, PAM helper, and
# CachyOS package/bootstrap state through system-manager.
assert system.users.users.mei.uid == 1000;
assert system.users.users.mei.group == "mei";
assert system.users.groups.mei.gid == 1000;
assert packageName system.users.users.mei.shell == "nushell";
assert lib.hasInfix "/run/system-manager/sw/bin/nu" system.environment.etc.shells.text;
assert system.security.wrappers.unix_chkpwd.setuid;
assert lib.hasInfix "unix_chkpwd" (toString system.security.wrappers.unix_chkpwd.source);
assert builtins.hasAttr "cachyos-bootstrap" system.systemd.services;
assert builtins.hasAttr "openrgb-udev-reload" system.systemd.services;
assert lib.elem "yay" system.standalone.cachyos.packages;
assert lib.elem "cachyos-gaming-meta" system.standalone.cachyos.packages;
assert lib.elem "cachyos-gaming-applications" system.standalone.cachyos.packages;
assert lib.elem "wine-mono" system.standalone.cachyos.packages;
assert lib.elem "winetricks" system.standalone.cachyos.packages;
assert lib.elem "mangohud" system.standalone.cachyos.packages;
assert lib.elem "gamemode" system.standalone.cachyos.packages;
assert lib.elem "fish" system.standalone.cachyos.removePackages;
assert system.standalone.cachyos.thyx.preset == "blush";
assert lib.hasInfix "Current=thyx" system.environment.etc."sddm.conf.d/00-system-manager-theme.conf".text;
assert lib.hasInfix "ThemeDir=/run/system-manager/sw/share/sddm/themes" system.environment.etc."sddm.conf.d/00-system-manager-theme.conf".text;
assert lib.hasInfix "i2c-dev" system.environment.etc."modules-load.d/i2c-dev.conf".text;
assert builtins.hasAttr "udev/rules.d/60-openrgb.rules" system.environment.etc;
assert builtins.hasAttr "systemd/user/app-steam@.service.d/10-system-manager-path.conf" system.environment.etc;
assert lib.hasInfix "Environment=PATH=/usr/local/sbin" system.environment.etc."systemd/user/app-steam@.service.d/10-system-manager-path.conf".text;
assert massive.home.file ? ".local/bin/steam";
assert hasPackages [ "thyx" "openrgb" "nushell" ] system.environment.systemPackages;
assert hasPackages [ "hydralauncher" "game-trainer" "gaming-health" "cheat-engine" ] massive.home.packages;
assert massive.home.file ? ".local/share/applications/game-trainer.desktop";
assert flake.packages.x86_64-linux ? thyx;

# Package policy still resolves the requested unfree packages.
assert !(policyConfig ? allowBroken);
assert !(policyConfig ? permittedInsecurePackages);
assert !(policyConfig ? allowUnfree);
assert policyConfig.allowInsecure == false;
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
