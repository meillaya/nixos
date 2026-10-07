# scripts/ - the hardware pipeline and the readiness probes

## OVERVIEW
Stdlib-only Python behind the `bin/` wrappers: hardware intake/enrollment for the install
path, and read-only readiness probes. Nothing here activates a machine by itself.

## STRUCTURE
```
scripts/
├── hardware/    # intake + enrollment pipeline (15 modules, cli.py is the entry)
├── readiness/   # home_preflight.py + task7/ production helpers
├── support/     # canonical_json.py, the shared canonical-JSON codec
└── check-unfree-pins.py  # unfree pin drift vs the resolved package policy
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Intake CLI | `hardware/cli.py` | `collect FIXTURE`, `create BASE PATCH HOST REVIEWER`, `validate INPUT PATCH` |
| Patch rules | `hardware/intake.py` | `MUTABLE_ROOTS` vs `IMMUTABLE_ROOTS`; parent replacement forbidden |
| Fixture validation | `hardware/collector.py` | 20 capability keys, route table, forbidden-field blacklist |
| Build the operator trust fixture | `hardware/gen_trust.py` | from repo facts; private key only in a 0600 temp file |
| Installer-side enrollment | `hardware/auto_enroll.py` | runs in the ISO; `auto_enroll_core.py` holds the logic |
| Key/recipient primitives | `hardware/trust.py` | ssh-ed25519, age recipients, sha256, all sorted-unique |
| Standalone HM preflight | `readiness/home_preflight.py` | read-only; reports boundaries, repairs nothing |
| Canonical JSON | `support/canonical_json.py` | `check` / `emit` CLI plus the shared codec |
| Unfree pin drift | `check-unfree-pins.py` | read-only; compares `config/package-exceptions.json` against the version `mkPkgs` resolves (nixpkgs plus multiverse pins) |

## COMMANDS
```bash
bin/nix-config-hardware-intake        collect|create|validate ...
bin/nix-config-hardware-collector     --fixture CANONICAL-FIXTURE.json
bin/nix-config-host-key-enroll        <host-key-file> <hostId>
PYTHONPATH=$PWD python3 scripts/hardware/gen_trust.py [--host remembrance] [-o OUT]
python3 -B -I scripts/support/canonical_json.py check FILE
python3 scripts/readiness/home_preflight.py --json [--fixture FILE]
python3 -B scripts/check-unfree-pins.py     # non-zero when a pin drifted
```

## CONVENTIONS
- Stdlib only, no external deps. Each module carries a PEP 723 header
  (`requires-python = ">=3.11"`, `dependencies = []`), so it runs with plain `python3`.
- Always invoke with `-B` (or `PYTHONDONTWRITEBYTECODE=1`) and `PYTHONPATH=<repo-root>` -
  the wrappers do this and import as `scripts.hardware.*`, `scripts.support.*`.
- Errors are typed (`ContractError`, `CanonicalJsonError`) and the CLI never prints prose
  into stdout data: fixtures and results are canonical JSON (sorted keys, compact, trailing
  newline). Usage errors exit 64, contract failures exit 1.
- Canonical means sorted keys AND compact separators: `config/package-exceptions.json` is
  pretty-printed and therefore fails `python3 -B -I scripts/support/canonical_json.py check`
  (exit 1). Only generated intake documents and fixtures are held to the byte-exact form.
- The collector never reads a device node. Device facts arrive as attended descriptor data
  and their digests are verified in Nix, not here.
- Every read is a plain file read with no side effects; enrollment is the only thing that
  writes, and it writes under `/root/enroll`.

## ANTI-PATTERNS
- Do not let MAC/IP/serial/UUID or free text leak into a fixture - the collector has an
  explicit `_walk_forbidden` gate and will reject it.
- Do not extend `IMMUTABLE_ROOTS` (hostId, target, system, role, identity,
  platformExpectations) with a patch - identity changes are not an intake operation.
- Do not treat the pipeline as authorization to install: `task7/installer.py` carries the
  `physical-install-requires-attended-run` sentinel, and physical installs stay attended.
- Do not commit `__pycache__`. `.gitignore` ignores it; any stray directory is local
  debris from a run that forgot `-B`.
- Do not add a shell-out where a pure validator would do; the trust primitives are pure by
  design so they can be reused in tests.
