{ ... }:
{
  # Evaluation inventory, not a claim that every target is enrolled for
  # production release or activation.
  flake.configurationEvaluationPaths = [
    "nixosConfigurations.remembrance"
    "darwinConfigurations.entropy"
  ];
}
