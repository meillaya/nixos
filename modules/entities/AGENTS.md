# modules/entities/ - the inventory and machine authority

## OVERVIEW
The only place hosts, homes, and machines are declared. No behavior lives here.

## STRUCTURE
```
entities/
├── hosts.nix                # den.hosts / den.homes - the registry
├── defaults.nix             # lib.types schemas + Den schema extensions
├── machine-authority.nix    # exposes flake.machineAuthority
└── _machine-authority/      # private: model.nix, validators.nix, crypto.nix
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add/remove a host or home | `hosts.nix` | asserts target names match `model.nix` |
| Change what a machine record may contain | `defaults.nix` | `machineType`, `identityType`, `bootType`, `storageType` |
| Enroll a machine | `_machine-authority/model.nix` | enrolled hosts read `config/hosts/intake/<host>.json` |
| Tighten validation | `_machine-authority/validators.nix` | closed `projectionFields` whitelist + cross-field rules |
| Verify recorded device digests | `_machine-authority/crypto.nix` | pure-Nix SHA-256, no external tools |

## CONVENTIONS
- Entity entries carry identity and membership ONLY: `system`, `hostName`, `machine`,
  `users.<name>.identity`. Aspect selection happens in `modules/aspects/`.
- `hosts.nix` opens with asserts tying every registered host to its `model.nix` target;
  adding a host without adding its machine record fails evaluation immediately.
- `getMachine` runs `validators.assertValid` on every read - an unvalidated record never
  reaches an aspect.
- `allowsSystemMutation` gates activation authority: true only when boot, storage, or
  capabilities are enrolled.
- Extended fields on a machine record must be added to the `machineType` freeform-plus-
  options schema and the `projectionFields` whitelist together, or the projection drops them.
- `declaredMachineIds` is the source for tests asserting the exact
  `nixosConfigurations` / `darwinConfigurations` / `homeConfigurations` sets.

## ANTI-PATTERNS
- Never project a literal machine id from an aspect; host-local facts must come from
  `host.machine` so projection cannot drift from the selected entity.
- Never make `machine` / `identity` a generic `attrs` or `raw` type - the architecture
  test fails on that regression explicitly.
- Never hand-write a machine record for an enrolled host; it is pipeline output
  (see `config/hosts/intake/README.md`).
- Never construct or import a NixOS/Darwin system here.
