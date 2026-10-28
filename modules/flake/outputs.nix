{ ... }:
{
  # Evaluation inventory, not a claim that every target is installed.
  flake.configurationEvaluationPaths = [
    "nixosConfigurations.remembrance"
    "nixosConfigurations.live"
    "nixosConfigurations.installed"
    "darwinConfigurations.entropy"
  ];
}
