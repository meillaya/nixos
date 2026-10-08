{ host, pkgs, lib, ... }:
let
  username = host.machine.identity.name;
in
{
  # Setup user, packages, programs
  nix = {
    package = pkgs.nix;

    settings = {
      # Hard-link identical files as they enter the store. A store carrying two
      # rustc, three llvm, and five apple-sdk versions then pays for their
      # common files once instead of once per version.
      auto-optimise-store = true;

      # The calendar job below cannot fire while the machine is off. Below
      # min-free the daemon collects dead paths itself, up to max-free. A
      # JetBrains IDE rebuild peaks near 16 GiB, so free space has to recover
      # before the next one starts.
      min-free = "15G";
      max-free = "45G";

      trusted-users = [ "@admin" username ];
      substituters = [
        "https://noctalia.cachix.org"
        "https://nix-community.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 2; Minute = 0; };
      options = "--delete-older-than 30d";
    };

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # launchd runs a missed StartCalendarInterval when the machine wakes from
  # sleep and drops it when the machine is powered off at the scheduled time.
  # Collect at load as well, and keep the job's output: Nix 2.34 writes no
  # /nix/var/nix/gc.log, so /var/log/nix-gc.log is the record that a run
  # happened and what it deleted.
  launchd.daemons.nix-gc.serviceConfig = {
    RunAtLoad = lib.mkForce true;
    StandardOutPath = "/var/log/nix-gc.log";
    StandardErrorPath = "/var/log/nix-gc.log";
  };

  # OmniWM is a menu-bar tiling window manager (LSUIElement), so the session is
  # only usable once it is running. RunAtLoad starts it at login, the earliest a
  # GUI app can run, since a LaunchDaemon has no Aqua session to own a status
  # item. KeepAlive.SuccessfulExit = false restarts it after a crash but leaves a
  # deliberate quit alone. Using `command` (rather than ProgramArguments) wraps
  # the binary in `/bin/wait4path /nix/store`, which matters on boot before the
  # store is mounted.
  #
  # Deliberately the /Applications/Nix Apps copy, not the /nix/store path from
  # modules/darwin/packages.nix: nix-darwin *copies* GUI bundles there, so it is
  # a different file from the store one, and it is the path OmniWM already holds
  # Accessibility permission for. The store path would read as a new app and
  # force a re-grant. Quoted because the path contains a space.
  launchd.user.agents.omniwm = {
    command = "'/Applications/Nix Apps/OmniWM.app/Contents/MacOS/OmniWM'";
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = { SuccessfulExit = false; };
      ProcessType = "Interactive";
      LimitLoadToSessionType = "Aqua";
    };
  };

  # Turn off NIX_PATH warnings now that we're using flakes

  # Remote Login (Apple's OpenSSH server). nix-darwin's default for this option
  # is null, which means "let macOS manage it", and macOS has it off, so the
  # Mac is unreachable over SSH until someone flips it in System Settings.
  # `true` makes activation bootstrap system/com.openssh.sshd itself.
  # The login key is declared in modules/darwin/system.nix, for both mei and
  # root, under users.users.<name>.openssh.authorizedKeys.
  services.openssh.enable = true;

  # Tailscale goes through nix-darwin's service module rather than a bare entry
  # in ./packages.nix, which only would have put the binaries on PATH. The
  # module adds pkgs.tailscale to environment.systemPackages itself, runs
  # `tailscaled` as a LaunchDaemon (RunAtLoad), and writes the MagicDNS
  # resolver stub for ts.net. Joining a tailnet stays a one-time
  # `sudo tailscale up`.
  services.tailscale.enable = true;

  # Load Darwin packages at the system level so nix-darwin copies GUI app
  # bundles into /Applications/Nix Apps, where LaunchServices and Spotlight can
  # discover them. Home Manager still installs the same package set for user
  # profile CLI access.
  environment.systemPackages = import ./packages.nix { inherit pkgs; };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];

  system = {
    # The optional uninstaller currently evaluates an internal default
    # nix-darwin system whose HTML manual still passes removed
    # nixos-render-docs TOC flags. Keep rebuild/version tools enabled, but
    # skip the uninstaller until upstream's manual renderer is compatible.
    tools.darwin-uninstaller.enable = false;

    checks.verifyNixPath = false;
    stateVersion = 5;

    defaults = {
      # Nine preferences moved out of this block because nix-plist-manager
      # writes the same plist keys, and a key with two authors is decided by
      # activation order: AppleShowAllExtensions, KeyRepeat, InitialKeyRepeat,
      # com.apple.sound.beep.volume, and the Dock's autohide, show-recents,
      # launchanim, orientation, and tilesize.
      #
      # Four more below are dual-writable and have only this one author today:
      # com.apple.mouse.tapBehavior, com.apple.sound.beep.feedback, and the
      # trackpad's Clicking and TrackpadThreeFingerDrag.
      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;

        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.feedback" = 0;
      };

      finder = {
        _FXShowPosixPathInTitle = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
    };
  };
}
