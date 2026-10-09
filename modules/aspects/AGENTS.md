# modules/aspects/ - the flat aspect tree

## OVERVIEW
Every aspect lives here, in one flat directory, alongside the entity registry and the
machine authority. `ls modules/aspects/` is the repository's table of contents; there are
no sub-classification folders. Behaviour lives in aspects, never in the registry.

## STRUCTURE
```
aspects/
├── inventory.nix            # den.hosts / den.homes - the ONE entity registry
├── schema.nix               # lib.types schemas + Den schema extensions
├── authority.nix            # exposes flake.machineAuthority
├── _machine-authority/      # private: model.nix, validators.nix, crypto.nix
├── nixpkgs.nix              # shared-policy: nixpkgs config + overlays
├── linux.nix, darwin.nix    # OS baseline chains
├── workstation-*.nix        # role aggregators
├── <host>.nix               # remembrance, antagony, entropy, massive
├── storage-<host>.nix       # per-host boot/storage branch
├── <capability>.nix         # leaf feature aspects
└── mei.nix                  # the user entity + cross-platform HM payload
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add/remove a host or home | `inventory.nix` | asserts target names match `_machine-authority/model.nix` |
| What does machine X do | `<host>.nix` | its asserts, `includes`, and host-specific overrides |
| Change what a machine record may contain | `schema.nix` | `machineType`, `identityType`, `bootType`, `storageType` |
| Enroll a machine | `_machine-authority/model.nix` | enrolled hosts read `config/hosts/intake/<host>.json` |
| Tighten validation | `_machine-authority/validators.nix` | closed `projectionFields` whitelist + cross-field rules |
| Verify recorded device digests | `_machine-authority/crypto.nix` | pure-Nix SHA-256, no external tools |
| Add a shared capability | a new `<kebab-name>.nix` | select it from a platform/role aggregator |

## CONVENTIONS
- Entity entries carry identity and membership ONLY: `system`, `hostName`, `machine`,
  `users.<name>.identity`. Host-specific behaviour lives in the `<host>.nix` aspect.
- `inventory.nix` opens with asserts tying every registered host to its
  `_machine-authority/model.nix` target; adding a host without adding its machine record
  fails evaluation immediately.
- `getMachine` runs `validators.assertValid` on every read - an unvalidated record never
  reaches an aspect.
- `allowsSystemMutation` gates activation authority: true only when boot, storage, or
  capabilities are enrolled.
- Extended fields on a machine record must be added to the `machineType` freeform-plus-
  options schema and the `projectionFields` whitelist together, or the projection drops them.
- `declaredMachineIds` is the source for tests asserting the exact
  `nixosConfigurations` / `darwinConfigurations` / `homeConfigurations` sets.
- Machine data reaches an aspect only as `host.machine`. No aspect imports
  `_machine-authority` or calls `authority.getMachine`; `inventory.nix` and
  `modules/flake/iso-images.nix` are the only two readers, and
  `tests/dendritic-architecture.sh` enforces it.
- A capability only one host uses belongs inline in that host's file. Promote it to its
  own `<capability>.nix` once a second host needs it.

## ANTI-PATTERNS
- Never project a literal machine id from an aspect; host-local facts must come from
  `host.machine` so projection cannot drift from the selected entity.
- Never make `machine` / `identity` a generic `attrs` or `raw` type - the architecture
  test fails on that regression explicitly.
- Never hand-write a machine record for an enrolled host; it is pipeline output
  (see `config/hosts/intake/README.md`).
- Never construct or import a NixOS/Darwin system here.
- Never add a sub-folder under `aspects/`. The flat directory is the discovery mechanism,
  and the architecture test fails if `features/`, `platforms/`, `roles/`, `hardware/`,
  `storage/`, `named-hosts/`, `users/`, or `entities/` comes back.
