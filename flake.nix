{
  description = "Personal NixOS config: workstation hosts on NixOS and macOS";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    emacs-overlay = {
      url = "github:dustinlyons/emacs-overlay";
      flake = false;
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };
    noctalia = {
      # Track the latest Noctalia commit that upstream has already cached.
      # Keep this input independent from our nixpkgs pin so Noctalia's
      # Cachix artifacts remain usable. zix passes `-I noctalia` to auto-follow
      # for the same reason, or the next `zix follows fix` would fold this input
      # onto our pin.
      url = "github:noctalia-dev/noctalia/cachix";
    };
    # stylix pins nix-systems/default at the future-26.11 branch while every
    # other input takes the default branch, which left a second systems node in
    # the lock. A root input gives stylix something to follow so the dedupe gate
    # is satisfied; both branches carry the systems this fleet builds.
    systems.url = "github:nix-systems/default";
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };
    nh = {
      url = "github:nix-community/nh";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-plist-manager = {
      url = "github:sushydev/nix-plist-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preservation.url = "github:nix-community/preservation";
    den.url = "github:denful/den/1614f6f8ed435c5bb257408bf91fd662f9aac43e";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    # deploy-rs and helium each carry their own flake-compat input, which left
    # two nodes in the lock. auto-follow can only point a consumer at a root
    # input, so the dedupe needs flake-compat declared here first.
    flake-compat.url = "github:edolstra/flake-compat";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };
    # System-level declarative configuration for the standalone (non-NixOS)
    # host, which Home Manager cannot reach. See modules/flake/system-manager.nix.
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    multiverse.url = "github:fzakaria/nixpkgs-multiverse";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules/flake);
}
