# modules/ - the dendritic graph

## OVERVIEW
Every fleet output is composed here: Den entities declare hosts and users, Den
aspects own behavior, and flake-parts owns per-system outputs. There is no
machine authority and no per-host storage branch. The distro is a separate
flake under `distro/`; it is not composed here.

## STRUCTURE
```
modules/
├── aspects/        # FLAT: hosts, roles, platforms, feature aspects
├── flake/          # flake-parts outputs
├── nixos/          # low-level NixOS and Home Manager payload
├── darwin/         # low-level nix-darwin payload
├── shared/         # cross-platform Home Manager payload
├── linux/          # Linux Home Manager payload
└── standalone-linux/
```

## COMPOSITION
An aspect is a function of platform class:

```nix
{ inputs, ... }:
{
  den.aspects.niri.nixos = import ../nixos/niri.nix { inherit inputs; };
}
```

The fleet chain is inward-only:

```text
named host -> workstation-role -> platform -> feature aspects
```

The distro is not a second chain. `distro/flake.nix` extends
`nixosConfigurations.remembrance` and adds `distro/modules/*`, which are raw
NixOS modules using `config.distro.liveUser` instead of a literal identity.

## HOST DATA
- `inventory.nix` carries `users.<name>.identity` only.
- Host aspects read `host.users.mei.identity` and `host.hostName`.
- No `machine`, `boot`, `storage`, `capabilities`, or `remoteInstall` record.
- No disk ID or UUID. `modules/nixos/storage-labels.nix` mounts `NIXBOOT` and
  `NIXROOT`; the installer creates them. `my.storage.labels.enable = false`
  opts the live ISO out.

## ADD A HOST
1. Add the entity in `inventory.nix` with `users.mei.identity`.
2. Add `aspects/<host>.nix` selecting the role, storage, and host hardware.
3. Update the name sets in `tests/dendritic-config-eval.nix`.
4. Add `storage-labels` if the host installs to a disk.

## ADD A FEATURE
1. Add one flat `modules/aspects/<kebab-name>.nix`.
2. Put raw implementation in `modules/nixos`, `modules/darwin`,
   `modules/shared`, `modules/linux`, or `modules/standalone-linux`.
3. Select it from a platform or role aggregator, not from a host directly.

## FLAKE WIRING
| File | Job |
|------|-----|
| `flake/dendritic.nix` | imports Den strict and `import-tree ../aspects` |
| `flake/systems.nix` | `x86_64-linux`, `aarch64-darwin` |
| `flake/apps.nix` | build/switch/update/clean apps and the zix app |
| `flake/checks.nix` | per-system checks, including `agent-settings` |
| `flake/packages.nix` | `zix`, Excalidraw, and `agent-settings` packages |
| `flake/system-manager.nix` | `systemConfigs.massive` |

The ISO, installer, live, and installed modules live in `distro/` and have
their own flake outputs.

## CONVENTIONS
- Identity comes from `host.users.mei.identity`; never a literal.
- Raw distro modules use `config.distro.liveUser`.
- Storage is a label contract, never a disk ID.
- Aspect names are kebab-case; class payloads are `nixos`, `darwin`,
  `homeManager`.
- Nushell is the login shell; Bash is the only fallback.

## ANTI-PATTERNS
- No `_machine-authority`, intake JSON, enrollment scripts, or
  `flake.machineAuthority`.
- No `host.machine`, `diskById`, `storage.profile`, or disko device.
- No `specialArgs` or `extraSpecialArgs`.
- No `nixosSystem` in `flake.nix`; Den creates fleet configurations.
- No sub-folders under `aspects/`.
- No `live`/`installed` aspects, ISO wiring, or distro modules in the main
  flake.
- No second Niri session authority; Noctalia owns bar, notifications, lock, and
  wallpaper.
- No fish or zsh shell configuration.
