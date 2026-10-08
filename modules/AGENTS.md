# modules/ - the dendritic graph

## OVERVIEW
Every flake output you care about is composed here: Den entities declare machines,
Den aspects own behavior, and flake-parts owns outputs per system.

## STRUCTURE
```
modules/
├── entities/       # the inventory (den.hosts, den.homes) + machine authority
├── aspects/        # ALL behavior: the only layer that may select capabilities
│   ├── features/   # 14 leaf capability aspects, one file each
│   ├── platforms/  # linux.nix, darwin.nix - OS baseline chains
│   ├── roles/      # workstation-linux, workstation-darwin, qualifier-linux, evaluation-linux
│   ├── hardware/   # vendor + capability routing, projection-only
│   ├── storage/    # per-host disko/profile selection
│   ├── named-hosts/# per-host identity projection (remembrance, antagony, entropy)
│   ├── hosts/      # compatibility aggregates (nixos-workstation, darwin-workstation, massive)
│   ├── users/      # mei.nix - the user entity + cross-platform HM payload
│   └── shared-policy/
├── flake/          # the 10 flake-parts modules (see below)
├── nixos/          # low-level NixOS/HM modules - imported by aspects, never by flake.nix
├── darwin/         # low-level nix-darwin modules
├── shared/         # cross-platform HM payload for the mei user
├── linux/          # Linux HM payload shared by NixOS and massive
└── standalone-linux/  # the standalone host's Home Manager home and system-manager layer
```

## HOW COMPOSITION WORKS
An aspect is a function keyed by platform class:

```nix
{ inputs, ... }:
{
  den.aspects.niri.nixos = import ../../nixos/niri.nix { inherit inputs; };
}
```

The full chain, inward-only - a layer may include the next, never the reverse:

```
named host -> storage -> hardware routing -> role -> platform -> feature aspects
```

- `den.aspects.<x>.includes = [ ... ]` composes by name; peers are always referenced
  as `den.aspects.<peer>`, never by string or via `self`.
- The host argument carries the validated record: use `host.machine.identity`,
  `host.machine.role`, `host.system`. Do not re-read a literal global machine id.
- User-level content belongs on `den.aspects.mei.homeManager`, or on a feature with
  `provides.to-users` when the host genuinely selects that payload.
- `import-tree ../entities` and `import-tree ../aspects` in `modules/flake/dendritic.nix`
  auto-load every file, so a new aspect needs no registry edit.

## ADD A HOST
1. Machine record: committed intake JSON (`config/hosts/intake/<host>.json`) for an
   enrolled machine, else an inline pending record in `_machine-authority/model.nix`.
2. Register in `entities/hosts.nix` under `den.hosts.<system>.<name>` (identity + membership only).
3. Thin named-host aspect in `aspects/named-hosts/<host>.nix` that asserts the machine
   target/system/role and `mkForce`s hostname + locale from `host.machine`.
4. Add `aspects/storage/<host>.nix`, and an ISO entry only if it needs one
   (`modules/flake/iso-images.nix`, `isoHosts`).
5. Update expectations: `tests/dendritic-config-eval.nix` asserts the exact
   `nixosConfigurations` / `darwinConfigurations` / `homeConfigurations` name sets, the
   per-system `flake.apps` list, and `flake.configurationEvaluationPaths`.

## ADD A FEATURE ASPECT
1. `modules/aspects/features/<kebab-name>.nix`, one aspect, file stem == aspect name.
2. Give it `nixos` / `darwin` / `homeManager` payloads or `includes`; keep the
   implementation module in `modules/nixos/`, `modules/darwin/`, or `modules/shared/`.
3. Select it from a platform or role aggregator (`aspects/platforms/*.nix`,
   `aspects/roles/*.nix`) - hosts do not select features directly.

## FLAKE WIRING
| File | Job |
|------|-----|
| `flake/dendritic.nix` | the whole graph: imports Den + `den.flakeModules.strict`, then `import-tree ../entities` and `import-tree ../aspects`; this is what makes a new aspect file live with no registry edit |
| `flake/systems.nix` | the two evaluation systems (x86_64-linux, aarch64-darwin) |
| `flake/apps.nix` | per-system `apps`, wrapping the committed `apps/<system>/<name>` scripts |
| `flake/checks.nix` | per-system checks running `tests/*.sh` in a sandbox |
| `flake/packages.nix` | per-system `packages`: `zix`, built from `tools/zix/package.nix`; host package sets still flow through `lib/nixpkgs.nix` |
| `flake/dev-shells.nix` | the single default devShell |
| `flake/outputs.nix` | `configurationEvaluationPaths` evaluation inventory |
| `flake/iso-images.nix` | `flake.iso.<host>`; each ISO carries the `hardware-enroll` oneshot |
| `flake/deploy-rs.nix` | `flake.deploy.nodes` for the four hosts + deployChecks in `flake.checks` |
| `flake/system-manager.nix` | `flake.systemConfigs.massive`: the standalone host's hostname and systemd units, applied with numtide/system-manager |

## MACHINE AUTHORITY
`_machine-authority/` is the trust boundary, not a data bag:
- `model.nix` - the `machines` attrset, `getMachine`, `allowsSystemMutation`; enrolled
  hosts read the committed intake JSON, so re-enrollment replaces the file and the
  build-time record follows automatically.
- `validators.nix` - a closed projection whitelist plus cross-field validation; fields
  outside `projectionFields` are dropped from the projection and inconsistent
  identity/platform combinations fail validation.
- `crypto.nix` - pure-Nix SHA-256 used to verify recorded device digests.
- `defaults.nix` - the `lib.types` schemas for identity, boot, storage, capabilities,
  and the Den schema extensions for host/home/user/aspect/flake.

`allowsSystemMutation` is true only when boot, storage, or capabilities are enrolled -
that is what keeps a disabled machine buildable but not activatable.

## CONVENTIONS
- Directories whose name starts with `_` (`_machine-authority`) are private internals.
- Identity is never a literal: `host.machine.identity`, `user.identity` are the only sources.
- Disk targets are `/dev/disk/by-id` basenames, never kernel device paths.
- Aspect names are kebab-case; class payloads are exactly `nixos`, `darwin`, `homeManager`.

## HOTSPOTS
| File | Lines | Why it matters |
|------|-------|----------------|
| `linux/home-manager.nix` | ~790 | the whole desktop payload; every Linux host and massive |
| `entities/_machine-authority/validators.nix` | ~610 | edit here and every machine record is re-checked |
| `shared/home-manager.nix` | ~605 | cross-platform user config; affects all four hosts |
| `flake/apps.nix` | ~485 | all app surfaces incl. `update` and `home-switch` |
| `_machine-authority/crypto.nix` | ~340 | pure-Nix hashing; slow to evaluate if misused |
| `aspects/users/mei.nix` | ~190 | user identity, HM payload, key activation scripts |

Platform and role aggregators (`linux-platform`, `workstation-role-linux`, `sops`,
`nixos-base`, `shared-policy`) are the choke points: editing one changes every host.
