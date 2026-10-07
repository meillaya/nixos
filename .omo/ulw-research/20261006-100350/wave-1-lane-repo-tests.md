# Wave 1 — lane1-repo-tests (librarian, completed 1m39s)

Digest: every repo test/readiness assertion that constrains a zero-touch install change.

## Pinned contracts

1. `tests/bootstrap-password-lifecycle.sh` (manual suite, not in `nix flake check`):
   pinned to host `remembrance`/user `mei` (`:8`); extracts the real
   `system.activationScripts.bootstrapPasswordHash.text` + `consumeBootstrapPassword.text`
   (`:10-13`). Accepts only `$y$` yescrypt, single newline-terminated line, salt 1..86,
   numeric 0:0, dir 0700 file 0600, no symlinks; consumes the hash into a `!` sentinel
   after `users` runs (`:182-250`).
2. `tests/bootstrap-password-secret-scan.sh`: no plaintext password, no inline `$y$` hash,
   no private-key markers in tracked `.nix` under hosts/modules/bin/docs/flake.nix/overlays
   (`:33,44-55,345-347`); a `hashedPasswordFile = "..."` reference is allowed (negative
   control `:435-441`).
3. `tests/dendritic-config-eval.nix:232` pins
   `users.users.mei.hashedPasswordFile == "/var/lib/nixos-bootstrap/mei-password.hash"`.
4. App surface is pinned in two exact lists (`tests/dendritic-apps.sh:40-51`,
   `tests/dendritic-config-eval.nix:13-15,146-149`); `apps/x86_64-linux/{build,build-switch,clean,install}`
   must exist and be executable; the install app's `--dry-run` plan must contain
   `--install-only` and `auto_enroll` (`dendritic-apps.sh:25-29`).
5. `tests/readiness/task7/test-static.sh:10` requires
   `physical-install-requires-attended-run` in `scripts/readiness/task7/installer.py`;
   `test-static.sh:7` forbids kernel device placeholders in `disk-config.nix` + the disko doc.
6. `tests/bootstrap-password-config-eval.nix` is ORPHANED: nothing imports it; its
   expectations run nowhere.

## Coverage verdicts for the four proposed changes

| Change | Constraint level |
|---|---|
| stage password hash into target | module/activation layer heavily pinned; the staging mechanism itself untested |
| write enrollment artifacts into installed system | no test asserts destination (fixtures only) |
| ISO oneshot auto-running the install | ZERO coverage (no test references flake.iso/iso-images/hardware-enroll/VARIANT_ID) |
| add a flake app or script | tightly constrained by the two exact name lists + executability + shim |

Raw detail: lane1's full report is in the session transcript (this digest keeps the
assertions that matter for the design).
