# tests/ - the invariants this repo refuses to break

## OVERVIEW
Bash and Nix checks that pin the dendritic architecture, the fleet evaluation,
the switch-script contract, and the zix developer tool. The distro's config and
installer tests live under `distro/tests/` and run from its own flake.

## STRUCTURE
```
tests/
├── dendritic-architecture.sh   # flat aspects, host data, distro boundary
├── dendritic-boundaries.sh     # identity sources, no disk IDs, retired stack
├── dendritic-apps.sh           # app inventory and wrapper contract
├── dendritic-shells.sh         # Nushell and Bash resolve to store paths
├── dendritic-config-eval.nix   # evaluates the personal hosts and policy
├── script-args.sh              # build-switch host default and argument passing
├── prose.sh                    # house prose rules
└── zix.sh                      # zix unit tests and offline smoke checks

distro/tests/
├── config-eval.nix             # live, installed, ISO and real-profile checks
└── installer-disk-vm.nix       # blank-disk partition/label/subvolume test
```

## COMMANDS
```bash
nix flake check --all-systems --no-build
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-apps.sh
bash tests/dendritic-shells.sh
bash tests/script-args.sh
bash tests/prose.sh
bash tests/zix.sh
nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'

cd distro
nix flake check
nix build .#checks.x86_64-linux.installer-disk-vm
```

## CONVENTIONS
- Every script starts `set -euo pipefail` and resolves the repo root from
  `BASH_SOURCE`.
- These are grep/assert tests over real files. Renaming a module updates the test
  in the same change.
- `dendritic-config-eval.nix` is the assertion wall for the personal hosts and
  the package policy. It does not evaluate the distro; `distro/tests` does.
- `script-args.sh` stubs `nh` and must keep `build-switch -- --dry` a dry run.
- The installer test runs `nixos-install-tui --test`: it creates labels,
  subvolumes, and mounts, then stops before copying a system.

## ANTI-PATTERNS
- Do not reintroduce `bootstrap-password-*`, `install-staging`, `readiness`, or
  `iso-autostart` tests; those paths were removed with the machine authority.
- Do not move the distro's ISO or installer tests back into the main flake.
- Do not silence a failing check by deleting its assertion. Replace the
  invariant when the architecture changes.
- Do not run the installer test against a real disk; it only uses the VM's
  `/dev/vdb`.
