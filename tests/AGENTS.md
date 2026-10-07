# tests/ - the invariants this repo refuses to break

## OVERVIEW
Bash and Nix checks that pin the dendritic architecture, package policy, and first-install
behavior. Cheap ones run in `nix flake check`; the password ones mutate system state.

## STRUCTURE
```
tests/
├── dendritic-architecture.sh   # the graph must stay dendritic + schema types stay strict
├── dendritic-boundaries.sh     # no hidden coupling, no identity literals, no retired stack
├── dendritic-apps.sh           # app inventory + the embedded updater python compiles
├── dendritic-shells.sh         # declared shells resolve to real store paths
├── dendritic-config-eval.nix   # evaluates remembrance + entropy configs and asserts the full contract
├── package-policy.sh           # no ad-hoc derivations, unfree allowlist discipline
├── prose.sh                    # house prose rules via tools/check-prose.py
├── zix.sh                      # zix CLI: unit tests + offline dry-run smoke checks
├── noctalia-cachix-script.sh   # the cachix writer stays idempotent and recoverable
├── bootstrap-password-*.{sh,nix}  # DESTRUCTIVE-RISK: first-install password lifecycle
└── readiness/                  # the G012 fixture harness (see its own AGENTS.md)
```

## COMMANDS
```bash
nix flake check --all-systems --no-build     # runs the .sh checks + config-eval + shells
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-apps.sh
bash tests/dendritic-shells.sh
bash tests/package-policy.sh
bash tests/prose.sh
bash tests/zix.sh
nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'
# prints: dendritic-config-eval=PASS
```

## WHERE TO LOOK
| Change | Test that will catch you |
|--------|--------------------------|
| Adding a host | `dendritic-config-eval.nix` (exact configuration name sets) |
| Adding/removing a flake app | `dendritic-apps.sh` + `dendritic-config-eval.nix` (`apps.x86_64-linux` set) |
| Weakening a machine/identity type | `dendritic-architecture.sh` |
| Adding `specialArgs` or a `runCommand` in production modules | `dendritic-boundaries.sh`, `package-policy.sh` |
| Hand-editing zix-managed files or marker blocks | `tests/zix.sh` (dry-run smoke) + `nix run .#zix -- doctor` |
| Hardcoding `mei` / `/home/mei` in an active module | `dendritic-boundaries.sh` |
| Reintroducing polybar/dunst/rofi/waybar/mako/picom/bspwm/etc. | `dendritic-boundaries.sh`, `dendritic-config-eval.nix` |
| Touching an unfree package | `package-policy.sh` + `config/package-exceptions.json` |
| Writing prose with a banned tell | `prose.sh` (`tools/check-prose.py`) |
| Changing NixOS aspects or install docs | the `bootstrap-password-*` suite |

## CONVENTIONS
- Every script starts `set -euo pipefail` and resolves the repo root from `BASH_SOURCE`,
  or honours an override env var (`DENDRITIC_POLICY_REPO_ROOT`, `DENDRITIC_TARGET_SYSTEM`).
- These are grep/assert tests, not unit tests: they read the real files with explicit
  paths, so renaming a module means updating the test in the same change.
- `dendritic-config-eval.nix` is an assertion wall over the evaluated remembrance and
  entropy configs. It is the only test that proves wiring end to end; extend it when you
  add a capability, do not add a parallel test file.
- CI equivalence: `modules/flake/checks.nix` wraps the same scripts as `perSystem` checks.

## ANTI-PATTERNS
- Do not treat `bootstrap-password-lifecycle.sh` as harmless: it wraps the activation
  scripts in `unshare -Ur -m` and `mount --bind`s fake `/var/lib`, `/etc/shadow`,
  `/etc/passwd`, `/etc/group`, and `/etc/nsswitch.conf`. Inside the namespace the host is
  untouched, but without namespace support those binds land on the real paths. Run it only
  for an install or password change, from a clean tree.
- Do not run `tests/bootstrap-password-secret-scan.sh` on a dirty tree: it is a scanner
  with a fixed scope list (`hosts`, `modules`, `bin`, `docs`, `flake.nix`, `overlays`), and
  its race cases mutate the worktree (temporarily moving `modules`, `git restore`) before
  revalidating. Commit or stash first.
- Do not silence a failing check by deleting its assertion; these greps are the contract.
