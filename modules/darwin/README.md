# Darwin implementation modules

These low-level modules are composed by the Darwin capability aspects under
`modules/aspects/`; Den creates the actual Darwin entities.

```text
base.nix        macOS defaults, Nix policy, fonts, and system packages
dock/           Declarative Dock option and activation implementation
system.nix      User home facts and Dock entries
user-home.nix   Darwin-specific Home Manager payload
packages.nix    Darwin package list
secrets.nix     Darwin sops-nix settings (removed in Phase 1)
```

Add machines in `modules/aspects/inventory.nix` and attach a thin aggregate aspect;
do not add `darwinSystem` calls to `flake.nix`.
