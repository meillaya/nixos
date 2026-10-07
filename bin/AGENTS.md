# bin/ - operator entry points and the destructive-action gates

## OVERVIEW
The four commands an operator runs by hand. Three delegate to `scripts/`, one is the whole
install flow. Every one of them either requires root, requires `--yes`, or only prints.

## STRUCTURE
```
bin/
├── host-install.sh              # the install orchestrator (bash)
├── _install-staging.sh          # sourced tmpfs staging builder (private)
├── nix-config-hardware-intake   # shim -> scripts/hardware/cli.py
├── nix-config-hardware-collector# shim -> cli.py collect (--fixture only)
├── nix-config-host-key-enroll   # shim -> _host_key_enroll.py
├── _host_key_enroll.py          # sops re-encrypt of the host key field (python)
└── setup-noctalia-cachix.sh     # writes the Nix binary-cache union (bash)
```

## COMMANDS
```bash
bin/host-install.sh --target-host <ip> --yes          # full enroll -> commit -> install -> verify
bin/host-install.sh --target-host <ip> --dry-run      # print the exact command plan, execute nothing
bin/host-install.sh --target-host <ip> --skip-install # enroll + commit only
bin/host-install.sh --target-host <ip> --yes --skip-verify
bin/host-install.sh --target-host <ip> --install-only # build gate + install for an enrolled worktree
bin/host-install.sh --target-host <ip> --yes --skip-fold  # keep the host key out of the sops store
bin/host-install.sh --target-host <ip> --yes --extra-files <dir>
bin/host-install.sh --target-host <ip> --yes --chown home/mei/.config 1000:100  # repeatable
bin/host-install.sh --target-host <ip> --yes --stage-identity ~/.config/sops/age/keys.txt
bin/nix-config-hardware-intake collect|create|validate ...
bin/nix-config-hardware-collector --fixture CANONICAL-FIXTURE.json
bin/nix-config-host-key-enroll <host-key-file> <hostId>
sudo bin/setup-noctalia-cachix.sh                     # mutates /etc/nix and restarts nix-daemon
```

The target-side one-command entry point is the flake app
`nix run github:meillaya/nixos#install` (`apps/x86_64-linux/install`): it probes
this machine, writes the enrollment into a work tree, and delegates the
destructive phase to `host-install.sh --install-only`.

## TRANSPORT FLAGS
`--extra-files <dir>` and repeatable `--chown <path> <owner>` forward straight to
`nixos-anywhere`; the caller supplies every ownership path, so the script never
defaults one. On the operator entry point (not `--install-only`) the script mints a
per-install password with the sourced helper `bin/_install-staging.sh`, stages it
(plus, with `--stage-identity SRC`, the age identity at
`home/<user>/.config/sops/age/keys.txt`) and prints the password once. Without
`--stage-identity` it stages no identity, so it forwards no `--chown`. It writes
`/run/autoinstall-done` immediately before the `nixos-anywhere` call so a
re-entrant run in the same boot does not fire the destructive install twice.

## DESTRUCTIVE-ACTION GATES
| Command | Gate |
|---------|------|
| `host-install.sh` install stage | `--yes` required, and re-checked inside the stage itself |
| `host-install.sh` | `--target-host` required; nothing is guessed - not the ISO, not the address |
| `host-install.sh --dry-run` | prints the plan, mints the stage to validate `mkpasswd`, and prints no secret |
| `setup-noctalia-cachix.sh` | root; writes only its managed block, then restarts and verifies the daemon |
| `nix-config-hardware-intake` | writes no device, reboot, activation, key, or network state |
| `nix-config-host-key-enroll` | rewrites one field of the sops store, re-encrypted in place |

Read `bin/host-install.sh` before running any mode other than `--dry-run`. Its order is:
generate trust -> push + trigger the ISO `hardware-enroll` oneshot -> retrieve artifacts ->
`nh os build` gate -> `nixos-anywhere` -> post-install verify. On the operator path it
mints and stages the password (and any `--extra-files`/`--stage-identity` payload)
just before that destructive call. Artifact presence is the gate, because the oneshot
ends in `|| true`.
`--install-only` skips straight to the build gate for a worktree whose
`config/hosts/intake/<host>.json` already exists; `--skip-fold` still copies and
commits the intake, but leaves the host key in the staging directory and relaxes
the `secrets/remembrance-keys.yaml` commit check. The caller is then responsible
for storing that key; the `install` app now stages the enrollment artifacts into
the installed system anyway, so `--save DIR` is an optional extra copy rather than
a requirement.

## CONVENTIONS
- Wrappers are thin and identical in shape: `set -euo pipefail`, resolve the repo root from
  `BASH_SOURCE`, then `PYTHONPATH=$root PYTHONDONTWRITEBYTECODE=1 LC_ALL=C exec python3 -B ...`.
- `bin/nix-config-hardware-intake` passes arguments straight through; narrow wrappers
  (`-collector`) validate their own usage and exit 64 on misuse.
- `bin/_install-staging.sh` is sourced, never executed: `staging_init` (tmpfs `mktemp -d`
  plus an `EXIT` trap), `staging_password` (yescrypt via `mkpasswd --stdin`, regex-checked
  before it writes a 0600 file into a 0700 dir, printed once, `unset pw`), `staging_artifacts`,
  `staging_identity` (prints the `--chown` pair it wants; it never chowns itself), and
  `staging_plan`. The caller owns the plaintext and must never write it to disk.
- Tool roles are fixed: `nixos-anywhere` installs, `nh` is the pre-flight build gate and the
  day-2 switch tool. `nh` never installs.
- `setup-noctalia-cachix.sh` owns exactly one managed block (`# BEGIN/END
  setup-noctalia-cachix (managed)`) and never hand-edits the rest of the file. On Determinate
  systems the include lives in `nix.custom.conf`, never in the generated `nix.conf`.
- Test knobs, not test doubles: `NOCTALIA_CACHIX_TEST_MODE`, `NOCTALIA_CACHIX_TEST_ACTIVATION`,
  `NOCTALIA_CACHIX_TEST_SYSTEMCTL`, `NOCTALIA_CACHIX_TEST_NIX`, `NOCTALIA_CACHIX_CONF_DIR`
  exist so `tests/noctalia-cachix-script.sh` can drive the script with mocked commands.

## ANTI-PATTERNS
- Do not add `examples/` or `overlays/` directories: `package-policy.sh` fails when
  `overlays/` is non-empty, and no `examples/` exists while every listed anti-pattern is
  already enforced by a test.
- Never add a path that installs or erases without an explicit `--yes` in the same
  invocation. The gate is re-checked inside the destructive stage on purpose.
- Never build the ISO, boot the target, or guess the address from this script; the README
  names those as human prerequisites.
- Never chown anything but the caller-reported `home/<user>/.config` subtree, and never
  default a `--chown` path: `nixos-anywhere` runs `chown -R` after disko has already
  formatted the disk, so a wrong path aborts an install on a wiped disk.
- Never hand-edit `secrets/remembrance-keys.yaml`; use `nix-config-host-key-enroll`, which
  verifies the derived public key against the intake record before touching the store.
- Never run `setup-noctalia-cachix.sh` with a hand-written replacement for the managed block;
  a partial write is what the script's recovery path exists for.
