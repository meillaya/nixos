# NixOS implementation modules

These are low-level NixOS and Home Manager modules owned by capability aspects.
Machine inventory and composition live in `modules/entities/` and
`modules/aspects/`; do not import this directory recursively or construct hosts
in `flake.nix`.

## Layout

```text
config/                 Static desktop assets
disk-config.nix         Disko disk/partition declaration
files.nix               NixOS Home Manager files
home-manager.nix        Linux desktop Home Manager payload
niri.nix                Niri, portals, audio, and runtime services
packages.nix            NixOS user package list
secrets.nix             NixOS sops-nix settings (removed in Phase 1)
system.nix              Shared NixOS machine baseline
bootstrap-password.nix  First-install external password verifier
```

## Adding a host

1. Add the entity to `modules/entities/hosts.nix`:

   ```nix
   den.hosts.x86_64-linux.hostname = {
     aspect = den.aspects.hostname;
     users.mei = { };
   };
   ```

2. Define a thin aggregate aspect, normally reusing the workstation baseline:

   ```nix
   { den, ... }:
   {
     den.aspects.hostname.includes = [
       den.aspects.nixos-workstation
       den.aspects.hostname-hardware
     ];
   }
   ```

3. Put hardware or machine-only facts in a leaf capability:

   ```nix
   {
     den.aspects.hostname-hardware.nixos = {
       imports = [ ./hardware-configuration.nix ];
       networking.hostName = "hostname";
     };
   }
   ```

4. Verify without activating it:

   ```bash
   nix build .#nixosConfigurations.hostname.config.system.build.toplevel --dry-run
   ```

See `docs/architecture/dendritic.md` for ownership and routing rules.

Niri bindings live in `modules/linux/config/niri/config.kdl`.
