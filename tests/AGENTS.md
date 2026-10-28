# tests/ - the invariants this repo refuses to break

## OVERVIEW
Bash and Nix checks that pin the dendritic architecture, the distro storage
contract, package policy, and the installer's disk behavior. Cheap checks run in
`nix flake check`; the installer VM test is x86_64-linux only.

## STRUCTURE
```
tests/
├── dendritic-architecture.sh   # flat aspects, host data, no machine authority
├── dendritic-boundaries.sh     # identity sources, no disk IDs, retired stack
├── dendritic-apps.sh           # app inventory and wrapper contract
├── dendritic-shells.sh         # declared shells resolve to store paths
├── dendritic-config-eval.nix   # evaluates hosts, distro, ISO contract
├── installer-disk-vm.nix       # blank-disk partition/label/subvolume test
├── package-policy.sh           # no ad-hoc derivations, unfree discipline
├── prose.sh                    # house prose rules
├── zix.sh                      # zix unit tests and offline smoke checks
└── noctalia-cachix-script.sh   # cachix writer idempotence
```

## COMMANDS
```bash
nix flake check --all-systems --no-build
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-apps.sh
bash tests/dendritic-shells.sh
bash tests/package-policy.sh
bash tests/prose.sh
bash tests/zix.sh
nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'
nix build .#checks.x86_64-linux.installer-disk-vm
```

## CONVENTIONS
- Every script starts `set -euo pipefail` and resolves the repo root from
  `BASH_SOURCE`, or honours `DENDRITIC_POLICY_REPO_ROOT`.
- These are grep/assert tests over real files. Renaming a module updates the test
  in the same change.
- `dendritic-config-eval.nix` is the end-to-end assertion wall for the personal
  hosts, live/installed profiles, and ISO contract.
- The installer test runs `nixos-install-tui --test`: it creates labels,
  subvolumes, and mounts, then stops before copying a system.

## ANTI-PATTERNS
- Do not reintroduce `bootstrap-password-*`, `install-staging`, `readiness`, or
  `iso-autostart` tests; those paths were removed with the machine authority.
- Do not silence a failing check by deleting its assertion. Replace the
  invariant when the architecture changes.
- Do not run the installer test against a real disk; it only uses the VM's
  `/dev/vdb`.
