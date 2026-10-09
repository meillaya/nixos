# scripts/hardware/ - intake and enrollment pipeline

## OVERVIEW
The typed, fail-closed pipeline that turns observed hardware into a reviewed machine
declaration. It validates and patches canonical JSON; it never partitions or activates.

## STRUCTURE
```
hardware/
├── cli.py                  # entry: collect | create | validate
├── collector.py            # fixture declaration validation + forbidden-field gate
├── contracts.py            # shared contract types and errors
├── intake.py               # RFC-6902 patch engine with MUTABLE/IMMUTABLE roots
├── auto_enroll.py          # ISO-side arg parsing; auto_enroll_core.py does the work
├── enrollment.py           # enrollment record assembly
├── discover.py             # SSH wrapper around nixos-facter on the target
├── probe.py                # read-only hardware probing
├── operational.py          # operational helpers shared by the above
├── platform_expectations.py# per-platform expectation tables
├── primitives.py           # small shared value primitives
├── gen_trust.py            # emits the operator trust.json from repo facts
└── trust.py                # ssh-ed25519 / age / sha256 validators
```

## WHERE TO LOOK
| Change | File | Notes |
|--------|------|-------|
| What a patch may touch | `intake.py` | `MUTABLE_ROOTS` allowlist; scalars under an immutable root cannot be replaced |
| What a fixture may contain | `collector.py` | capability key set + route table + forbidden fields |
| What the installer detects | `auto_enroll_core.py` | disk discovery, identity generation, trust merge |
| What trust material is valid | `trust.py` | sorted-unique, typed, no free text |
| The trust fixture contents | `gen_trust.py` | built from the committed intake JSON + `.sops.yaml` recipients |

## INVARIANTS
- Two documents per host: `<host>.json` (the declaration, the single source of truth that
  `modules/aspects/_machine-authority/model.nix` imports) and `<host>.intake.json` (the
  digest-bound patch with reviewer and appliedAt).
- Identity, target, system, role, and platform expectations are immutable across an intake
  patch. Only location/display/boot/storage/trust/hardware-inventory roots may change.
- Enrollment fails closed: without `/root/enroll/trust.json` nothing is written.
- The target disk is discovered as an internal whole device, preferring the one already
  bound in the base declaration; `--disk` pins it when several are equivalent.
- The host's own identity key is generated fresh per install, so its public key rotates on
  every reinstall - never treat it as a stable identifier.
- No device node is read by the collector; disk facts are attended descriptor data whose
  digests are checked in Nix.

## ANTI-PATTERNS
- Do not add an `examples/` directory here - none exists, and the anti-patterns worth
  teaching are already enforced by `dendritic-boundaries.sh` and `package-policy.sh`.
- Never emit a non-canonical document: sorted keys, compact separators, trailing newline.
- Never write a fixture from a live probe that contains MAC/IP/serial/UUID/free text.
- Never bypass `assertValid`-style checks to make a fixture pass; the Nix side re-validates
  and a mismatch surfaces as an evaluation failure, not a helpful message.
- Never add a network fetch to a validator; trust primitives stay pure.
- `bin/nix-config-hardware-collector` only accepts `--fixture`; do not add a
  "collect-from-this-machine" mode - live collection belongs to the ISO oneshot.
