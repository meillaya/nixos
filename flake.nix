{
  description = "Personal NixOS and nix-darwin fleet: Den entities, Home Manager, and a separate distro flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
    nix-plist-manager = {
      url = "github:sushydev/nix-plist-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    den.url = "github:denful/den/1614f6f8ed435c5bb257408bf91fd662f9aac43e";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    # helium carries its own flake-compat input. The root declaration lets the
    # consumer follow one node instead of adding a second copy.
    flake-compat.url = "github:edolstra/flake-compat";
    # System-level declarative configuration for the standalone (non-NixOS)
    # host, which Home Manager cannot reach. See modules/flake/system-manager.nix.
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # zix pins real package versions (currently raycast) through this index.
    # It is a developer-tool input, not a host dependency.
    multiverse.url = "github:fzakaria/nixpkgs-multiverse";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules/flake);
}
