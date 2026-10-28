# modules/ - the dendritic graph

## OVERVIEW
Every output is composed here: Den entities declare hosts and users, Den aspects
own behavior, and flake-parts owns per-system outputs. There is no machine
authority and no per-host storage branch.

## STRUCTURE
```
modules/
├── aspects/        # FLAT: hosts, roles, platforms, features, distro aspects
├── flake/          # flake-parts outputs, including the live ISO
├── distro/         # live/installed/ISO/installer NixOS modules
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

The personal chain is inward-only:

```text
named host -> workstation-role -> platform -> feature aspects
```

The distro chain is `distro-platform -> distro-role -> live|installed`.
`modules/distro/*` are raw NixOS modules; they do not take the Den `host`
argument and use `config.distro.liveUser` instead of a literal identity.

## HOST DATA
- `inventory.nix` carries `users.<name>.identity` only.
- Host aspects read `host.users.mei.identity` and `host.hostName`.
- No `machine`, `boot`, `storage`, `capabilities`, or `remoteInstall` record.
- No disk ID or UUID. `modules/nixos/storage-labels.nix` mounts `NIXBOOT` and
  `NIXROOT`; the installer creates them.

## ADD A HOST
1. Add the entity in `inventory.nix` with `users.mei.identity`.
2. Add `aspects/<host>.nix` selecting the role and setting host locale/timezone.
3. Update the name sets in `tests/dendritic-config-eval.nix`.
4. Add `storage-labels` if the host installs to a disk.

## ADD A FEATURE
1. Add one flat `modules/aspects/<kebab-name>.nix`.
2. Put raw implementation in `modules/nixos`, `modules/darwin`,
   `modules/shared`, `modules/linux`, `modules/standalone-linux`, or
   `modules/distro`.
3. Select it from a platform or role aggregator, not from a host directly.

## FLAKE WIRING
| File | Job |
|------|-----|
| `flake/dendritic.nix` | imports Den strict and `import-tree ../aspects` |
| `flake/systems.nix` | `x86_64-linux`, `aarch64-darwin` |
| `flake/apps.nix` | build/switch/update/clean apps |
| `flake/checks.nix` | per-system checks and the installer VM test |
| `flake/packages.nix` | `zix` package |
| `flake/outputs.nix` | evaluation inventory |
| `flake/iso-images.nix` | `iso.live` and `isoConfig.live` |
| `flake/deploy-rs.nix` | deploy nodes for the four personal hosts |
| `flake/system-manager.nix` | `systemConfigs.massive` |

## CONVENTIONS
- Identity comes from `host.users.mei.identity`; never a literal.
- Raw distro modules use `config.distro.liveUser`.
- Storage is a label contract, never a disk ID.
- Aspect names are kebab-case; class payloads are `nixos`, `darwin`,
  `homeManager`.

## ANTI-PATTERNS
- No `_machine-authority`, intake JSON, enrollment scripts, or
  `flake.machineAuthority`.
- No `host.machine`, `diskById`, `storage.profile`, or disko device.
- No `specialArgs` or `extraSpecialArgs`.
- No `nixosSystem` in `flake.nix`.
- No sub-folders under `aspects/`.
- No second Niri session authority; Noctalia owns bar, notifications, lock, and
  wallpaper.
