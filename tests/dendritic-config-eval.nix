{ flake ? builtins.getFlake ("path:" + toString ../.) }:
let
  policy = import ../lib/nixpkgs.nix { inputs = flake.inputs; };
  policyConfig = policy.config;
  policyLinuxPkgs = policy.mkPkgs "x86_64-linux";
  nixos = flake.nixosConfigurations.remembrance.config;
  nixosFiles = import ../modules/nixos/files.nix {
    homeDirectory = nixos.home-manager.users.mei.home.homeDirectory;
  };
  authority = flake.machineAuthority;
  validators = import ../modules/entities/_machine-authority/validators.nix;
  shellName = shell: shell.pname or shell.name or (builtins.baseNameOf (toString shell));
  expectedLinuxApps = [
    "build" "build-switch" "clean" "home-news" "home-switch" "nh" "search-pkgs" "update"
  ];
  hasShell = name: shells: builtins.any (shell: shellName shell == name) shells;
  remoteCapabilityValues = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value =
          if builtins.elem name [ "install.remote" "network.ethernet" ] then
            { state = "present"; }
          else
            {
              state = "absent";
              reason = "deferred";
            };
      })
      validators.capabilityKeys
  );
  remoteCapableEnrolledFixture = {
    remoteInstall = true;
    capabilities = {
      state = "enrolled";
      values = remoteCapabilityValues;
    };
  };
  remoteInstallCapabilityPresent = machine:
    machine.capabilities.state == "enrolled"
    && machine.capabilities.values."install.remote".state == "present";
  hasInfix = flake.inputs.nixpkgs.lib.hasInfix;
  countExactLine = expected: text:
    builtins.length (
      builtins.filter
        (line: line == expected)
        (flake.inputs.nixpkgs.lib.splitString "\n" text)
    );
  packageName = package: package.pname or package.name or (builtins.baseNameOf (toString package));
  tryDrvPath = package: builtins.tryEval package.drvPath;
  hasPackages = names: packages:
    let present = map packageName packages;
    in builtins.all (name: builtins.elem name present) names;
  hasAnyPackage = names: packages:
    let present = map packageName packages;
    in builtins.any (name: builtins.elem name present) names;
  hasAnyHomeFile = names: files:
    builtins.any
      (file: builtins.any (name: hasInfix name file) names)
      (builtins.attrNames files);
  homeFileBySuffix = suffix: files:
    let
      matches = builtins.filter
        (name: flake.inputs.nixpkgs.lib.hasSuffix suffix name)
        (builtins.attrNames files);
    in
    if matches == [ ] then
      throw "missing home.file entry ending in ${suffix}"
    else
      files.${builtins.head matches};
  nixosNiriConfig = homeFileBySuffix ".config/niri/config.kdl"
    nixos.home-manager.users.mei.home.file;
  nixosNoctaliaConfig = homeFileBySuffix ".config/noctalia/config.toml"
    nixos.home-manager.users.mei.home.file;
  nixosKonsoleProfile = homeFileBySuffix ".local/share/konsole/Garuda.profile"
    nixos.home-manager.users.mei.home.file;
  noctaliaServiceCount = services:
    builtins.length (
      builtins.filter
        (name: hasInfix "noctalia" name)
        (builtins.attrNames services)
    );
  noctaliaSettings = nixos.programs.noctalia.settings or null;
  requiredLinuxApplications = [
    "calibre" "devenv" "gimp" "ghostty" "helium" "kitty" "obsidian"
    "ollama" "qbittorrent" "noctalia" "zen-beta"
  ];
  assertHm = hm:
    assert hm.programs.nushell.enable;
    assert hm.programs.nushell.settings.show_hints;
    assert hm.programs.nushell.settings.history.file_format == "sqlite";
    assert hm.programs.nushell.settings.history.sync_on_enter;
    assert hm.programs.nushell.settings.completions.algorithm == "fuzzy";
    assert hm.programs.nushell.settings.color_config.hints == "light_cyan";
    assert hasInfix ".nix-profile/bin" hm.programs.nushell.extraEnv;
    assert hasInfix "/home/mei/.opencode/bin" hm.programs.nushell.extraEnv;
    assert hasInfix "/run/current-system/sw/bin" hm.programs.nushell.extraEnv;
    assert hasInfix "fastfetch" hm.programs.nushell.extraConfig;
    assert hasInfix "which fastfetch" hm.programs.nushell.extraConfig;
    assert hm.programs.kitty.enable;
    assert hm.programs.kitty.settings.background == "#161925";
    assert hm.programs.kitty.settings.foreground == "#c3c7d1";
    assert hm.programs.kitty.settings.color1 == "#ed254e";
    assert hm.programs.kitty.settings.color2 == "#71f79f";
    assert hasInfix "/bin/nu --login" hm.programs.kitty.settings.shell;
    assert hm.programs.bash.enable;
    assert hm.programs.zsh.enable;
    assert hm.programs.fish.enable;
    assert hm.programs.git.settings.credential."https://github.com".helper != [ ];
    assert builtins.head hm.programs.git.settings.credential."https://github.com".helper == "";
    assert hasInfix "gh auth git-credential"
      (builtins.elemAt hm.programs.git.settings.credential."https://github.com".helper 1);
    assert builtins.head hm.programs.git.settings.credential."https://gist.github.com".helper == "";
    assert hasInfix "gh auth git-credential"
      (builtins.elemAt hm.programs.git.settings.credential."https://gist.github.com".helper 1);
    assert countExactLine "set -g allow-passthrough on"
      hm.programs.tmux.extraConfig == 1;
    assert countExactLine "set -g allow-passthrough on"
      hm.xdg.configFile."tmux/tmux.conf".text == 1;
    true;
in
assert builtins.attrNames flake.nixosConfigurations == [ "antagony" "remembrance" ];
assert builtins.attrNames (flake.darwinConfigurations or { }) == [ "entropy" ];
assert builtins.attrNames (flake.homeConfigurations or { }) == [ "standalone-linux" ];
assert builtins.attrNames (flake.overlays or { }) == [ ];
assert flake.configurationEvaluationPaths == [
  "nixosConfigurations.remembrance"
  "darwinConfigurations.entropy"
];
assert authority.machineIds == [
  "antagony"
  "entropy"
  "remembrance"
];
assert (authority.getMachine "remembrance").target == "nixosConfigurations.remembrance";
assert builtins.attrNames remoteCapabilityValues == validators.capabilityKeys;
assert remoteInstallCapabilityPresent remoteCapableEnrolledFixture;
assert remoteCapableEnrolledFixture.remoteInstall
  == (remoteCapableEnrolledFixture.capabilities.values."install.remote".state == "present");
assert !(policyConfig ? allowBroken);
assert !(policyConfig ? permittedInsecurePackages);
assert !(policyConfig ? allowUnfree);
assert policyConfig.allowInsecure == true;
assert policyConfig ? allowUnfreePredicate;
assert (tryDrvPath policyLinuxPkgs.google-chrome).success;
assert (tryDrvPath policyLinuxPkgs.obsidian).success;
assert !(tryDrvPath policyLinuxPkgs.steam).success;
assert builtins.attrNames flake.apps.x86_64-linux == expectedLinuxApps;
assert builtins.attrNames (flake.apps.aarch64-darwin or { }) == [
  "build" "build-switch" "clean" "search-pkgs" "update"
];
assert nixos.networking.hostName == "remembrance";
assert nixos.system.stateVersion == "21.05";
assert nixos.programs.niri.enable;
assert nixos.xdg.portal.enable;
assert nixos.services.displayManager.defaultSession == "niri";
assert nixos.services.displayManager.sessionData.sessionNames == [ "niri" ];
assert !nixos.services.xserver.windowManager.bspwm.enable;
assert nixos.networking.networkmanager.enable;
assert nixos.hardware.enableRedistributableFirmware;
assert nixos.hardware.wirelessRegulatoryDatabase;
assert nixos.programs.noctalia.enable;
assert nixos.programs.spicetify.enable;
assert nixos.programs.noctalia.systemd.enable;
assert nixos.programs.noctalia.recommendedServices.enable;
assert nixos.hardware.bluetooth.enable;
assert nixos.services.upower.enable;
assert nixos.services.power-profiles-daemon.enable;
assert hasPackages [ "noctalia" ] nixos.environment.systemPackages;
assert hasPackages requiredLinuxApplications (
  nixos.home-manager.users.mei.home.packages ++ nixos.environment.systemPackages
);
assert !(hasAnyPackage [
  "awww"
  "dunst"
  "i3lock"
  "i3lock-fancy-rapid"
  "mako"
  "picom"
  "polybar"
  "rofi"
  "rofi-calc"
  "waybar"
  "swaybg"
  "swaylock"
  "wlogout"
] (
  nixos.home-manager.users.mei.home.packages ++ nixos.environment.systemPackages
));
assert hasPackages [ "obsidian" ] (
  nixos.home-manager.users.mei.home.packages ++ nixos.environment.systemPackages
);
assert hasPackages [ "heroic" ] (
  nixos.home-manager.users.mei.home.packages ++ nixos.environment.systemPackages
);
assert !(hasPackages [ "steam" ] (
  nixos.home-manager.users.mei.home.packages ++ nixos.environment.systemPackages
));
assert noctaliaServiceCount nixos.systemd.user.services == 1;
assert noctaliaServiceCount nixos.home-manager.users.mei.systemd.user.services == 0;
assert nixos.systemd.user.services.noctalia.wantedBy == [ "graphical-session.target" ];
assert nixos.systemd.user.services.noctalia.serviceConfig.Restart == "on-failure";
assert hasInfix "/bin/noctalia" nixos.systemd.user.services.noctalia.serviceConfig.ExecStart;
assert noctaliaSettings == null || (
  noctaliaSettings.shell.launch_apps_as_systemd_services
  && noctaliaSettings.bar.main.enabled
  && noctaliaSettings.notification.enable_daemon
  && noctaliaSettings.wallpaper.enabled
);
assert !nixos.services.picom.enable;
assert !nixos.home-manager.users.mei.services.dunst.enable;
assert !nixos.home-manager.users.mei.services.polybar.enable;
assert !nixos.home-manager.users.mei.services.screen-locker.enable;
assert builtins.attrNames nixosFiles == [
  ".config/niri/config.kdl"
  ".config/noctalia/config.toml"
];
assert !(hasAnyHomeFile [
  ".config/bspwm/"
  ".config/mako/"
  ".config/polybar/"
  ".config/rofi/"
  ".config/sxhkd/"
  ".config/waybar/"
] nixos.home-manager.users.mei.home.file);
assert !hasInfix ''spawn-at-startup "noctalia"'' nixosNiriConfig.text;
assert !hasInfix "awww" nixosNiriConfig.text;
assert !hasInfix "mako" nixosNiriConfig.text;
assert !hasInfix "picom" nixosNiriConfig.text;
assert !hasInfix "swaybg" nixosNiriConfig.text;
assert !hasInfix "swww" nixosNiriConfig.text;
assert !hasInfix "waybar" nixosNiriConfig.text;
assert hasInfix ''spawn-sh "noctalia msg screen-lock"'' nixosNiriConfig.text;
assert nixos.users.users.mei.hashedPasswordFile == "/var/lib/nixos-bootstrap/mei-password.hash";
assert nixos.users.users.mei.isNormalUser;
assert nixos.users.users.mei.uid == 1000;
assert nixos.users.groups.users.gid == 100;
assert nixos.users.users.mei.home == "/home/mei";
assert builtins.all (group: builtins.elem group nixos.users.users.mei.extraGroups) [
  "wheel"
  "networkmanager"
  "docker"
  "i2c"
  "video"
];
assert shellName nixos.users.users.mei.shell == "nushell";
assert hasShell "nushell" nixos.environment.shells;
assert hasShell "bash" nixos.environment.shells;
assert hasShell "zsh" nixos.environment.shells;
assert hasShell "fish" nixos.environment.shells;
assert assertHm nixos.home-manager.users.mei;
assert hasInfix "/bin/nu --login" nixosKonsoleProfile.text;
"dendritic-config-eval=PASS"
