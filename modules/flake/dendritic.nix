{ inputs, ... }:
{
  # One import-tree root: every file under modules/aspects/ is a flake-parts
  # module. The raw NixOS / nix-darwin / home-manager payload is imported
  # explicitly by the aspect that owns it.
  imports = [
    inputs.den.flakeModule
    inputs.den.flakeModules.strict
    (inputs.import-tree ../aspects)
  ];
}
