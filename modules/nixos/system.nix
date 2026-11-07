{ config, host, pkgs, ... }:

let
  identity = host.users.mei.identity;
  user = identity.name;
  home = identity.home;
  caches = import ../../lib/nix-caches.nix;
  # The Wayland session the login greeter preselects. noctalia-greeter 1.5.0
  # matches the desktop entry's Name= field, so this is "Niri", not the
  # niri.desktop file stem.
  session = "Niri";
  # The identity home-manager installs on every host at ~/.ssh/id_github, and at
  # ~/.ssh/id_ed25519 when that path is free. That is the key a machine actually
  # presents, so interactive login has to accept it or every host-to-host SSH
  # falls back to a password. The public half lives in lib/keys.nix.
  keys = [ (import ../../lib/keys.nix).github ];
in
{
  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 42;
      };
      efi.canTouchEfiVariables = true;
    };
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
    # Uncomment for AMD GPU
    # initrd.kernelModules = [ "amdgpu" ];
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "uinput" ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    i2c.enable = true;
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  nix = {
    nixPath = [ "nixos=${home}/.local/share/src/nixos:/etc/nixos" ];
    settings = {
      allowed-users = [ "${user}" ];
      trusted-users = [ "@admin" "${user}" ];
      substituters = caches.substituters;
      trusted-substituters = caches.substituters;
      trusted-public-keys = caches.trustedPublicKeys;
    };

    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Manages keys and such
  programs = {
    gnupg.agent.enable = true;

    # Needed for anything GTK related
    dconf.enable = true;
  };

  # Noctalia Greeter owns the login screen through greetd. It replaced LightDM,
  # whose AccountsService default-session handoff failed on a fresh install with
  # "Failed to start session". greeter.toml is generated from these settings;
  # session.default preselects the niri desktop from the session desktop files.
  services.displayManager.noctalia-greeter = {
    enable = true;
    settings = {
      session.default = session;
      # Single-user workstation: open the password step for this account.
      user.default = user;
      keyboard = {
        layout = "us";
        # services.xserver.xkb does not feed a Wayland greeter.
        options = "ctrl:nocaps";
      };
      cursor = {
        theme = "Adwaita";
        size = 24;
      };
    };
  };

  # greetd runs the greeter and then the chosen session command itself, so its
  # service PATH must expose the system profile: niri-session comes from the
  # niri.desktop Exec line and the greeter session wrapper needs dbus-run-session
  # plus coreutils. NixOS builds a service PATH from this list option.
  systemd.services.greetd.path = [ config.system.path ];

  # Point the greeter at the session desktop files. The nixpkgs module does not
  # export XDG_DATA_DIRS to the service, and the wayland-sessions directory is
  # not linked into the system profile.
  services.greetd.settings.default_session.command =
    "${pkgs.coreutils}/bin/env"
    + " XDG_DATA_DIRS=${config.services.displayManager.sessionData.desktops}/share"
    + " ${pkgs.noctalia-greeter}/bin/noctalia-greeter-session";

  services = {
    xserver = {
      enable = true;

      # Uncomment these for AMD or Nvidia GPU
      # videoDrivers = [ "amdgpu" ];
      # videoDrivers = [ "nvidia" ];

      # Uncomment this for Nvidia GPU
      # This helps fix tearing of windows for Nvidia cards
      # services.xserver.screenSection = ''
      #   Option       "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
      #   Option       "AllowIndirectGLXProtocol" "off"
      #   Option       "TripleBuffer" "on"
      # '';

      xkb = {
        # Turn Caps Lock into Ctrl
        layout = "us";
        options = "ctrl:nocaps";
      };
    };

    # Better support for general peripherals
    libinput.enable = true;

    # Let's be able to SSH into this machine
    openssh.enable = true;

    # Tailscale: the NixOS module adds pkgs.tailscale and runs tailscaled as a
    # system service, so the shared Home Manager list leaves the package out.
    # Joining a tailnet stays a one-time `sudo tailscale up`.
    tailscale.enable = true;

    # Sync state between machines. Folders and devices stay user-managed:
    # overriding them with an empty set would wipe interactive configuration
    # on every activation.
    syncthing = {
      enable = true;
      openDefaultPorts = true;
      dataDir = "${home}/.local/share/syncthing";
      configDir = "${home}/.config/syncthing";
      user = "${user}";
      group = "users";
      guiAddress = "127.0.0.1:8384";

      settings = {
        options.globalAnnounceEnabled = false; # Only sync on LAN
      };
    };

    gvfs.enable = true; # Mount, trash, and other functionalities
    tumbler.enable = true; # Thumbnail support for images

  };

  # Enable CUPS to print documents
  # services.printing.enable = true;
  # services.printing.drivers = [ pkgs.brlaser ]; # Brother printer driver

  # Enable sound
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Video support
  hardware = {
    graphics.enable = true;
    # nvidia.modesetting.enable = true;

    # Enable Xbox support
    # xone.enable = true;

    # Crypto wallet support
    ledger.enable = true;
  };


  # Container engines are rootless-only; see
  # modules/aspects/rootless-containers.nix (rootless docker user
  # daemon + rootless podman user socket, no rootful daemon or docker group).

  # It's me, it's you, it's everyone
  users.users = {
    ${user} = {
      extraGroups = [
        # No "docker": rootless containers never need root-equivalent socket
        # access (see modules/aspects/rootless-containers.nix).
        "i2c"
        "video"
      ];
      openssh.authorizedKeys.keys = keys;
    };

    # Root uses the same fleet key because remote deployment and host-to-host
    # SSH run as root.
    root = {
      openssh.authorizedKeys.keys = keys;
    };
  };

  # Don't require password for users in `wheel` group for these commands
  security.sudo = {
    enable = true;
    extraRules = [{
      commands = [
       {
         command = "${pkgs.systemd}/bin/reboot";
         options = [ "NOPASSWD" ];
        }
      ];
      groups = [ "wheel" ];
    }];
  };

  fonts.packages = with pkgs; [
    dejavu_fonts
    emacs-all-the-icons-fonts
    fira-sans
    jetbrains-mono
    nerd-fonts.fira-code
    font-awesome
    noto-fonts
    noto-fonts-color-emoji
  ];

  environment.systemPackages = with pkgs; [
    gitFull
    inetutils
  ];

  system.stateVersion = "21.05"; # Don't change this
}
