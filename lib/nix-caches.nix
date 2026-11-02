# One cache list for NixOS, nix-darwin, and the standalone Home Manager host.
{
  substituters = [
    "https://noctalia.cachix.org"
    "https://nix-community.cachix.org"
    "https://cache.nixos.org"
  ];

  trustedPublicKeys = [
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];
}
