{ inputs, ... }:
{
  den.aspects.nix-direnv = {
    nixos = { pkgs, lib, ... }: {
      # nix-direnv is a drop-in replacement for the direnv bash hook:
      # it implements `use flake` / `use nix` faster and caches gc-roots.
      # Pair `modules/shared/packages.nix` (nix-direnv binary on PATH)
      # with `programs.direnv.enable = true` (the standard direnv module)
      # so the .envrc at the repo root picks up nix-direnv.
      programs.direnv.enable = true;
      environment.systemPackages = [ pkgs.direnv ];
    };
  };
}
