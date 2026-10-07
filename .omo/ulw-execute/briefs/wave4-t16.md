# Wave-4 brief — todo 16: make the installer medium boot (fix F-A)

Work ONLY in the worktree `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave4` (branch `thinkpad-zero-touch-install/wave4`, off main 5d4052f).
Read the plan `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md` (todo 16) and the F-A evidence
`/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/F-A-iso-boot-diagnosis.md` first.

## The defect (proven on the real medium)
A fresh boot of the shipped ISO aborts: `initrd-nixos-activation` runs all activation scripts
pre-switch-root; the live ISO's `/var` is a tmpfs, so `system.activationScripts.bootstrapPasswordHash`
fails with `bootstrap password hash validation failed: missing /var/lib/nixos-bootstrap/mei-password.hash`
and switch-root refuses (`os-release file is missing`) -> emergency mode. `consumeBootstrapPassword`
would fail the same way (it hard-fails when the hash file is absent).

## Required fix (minimal, ISO-only)
1. In `modules/flake/iso-images.nix`, add an ISO-only module to the `extendModules` list that
   neutralizes BOTH scripts on the installer variant:
   `system.activationScripts.bootstrapPasswordHash = lib.mkForce { deps = []; text = ""; };`
   `system.activationScripts.consumeBootstrapPassword = lib.mkForce { deps = []; text = ""; };`
   If the users activation also hard-fails on the missing `hashedPasswordFile`, neutralize that
   on the ISO too and document it.
2. Do NOT touch `modules/nixos/bootstrap-password.nix`. Prove the installed system is unchanged:
   eval `nixosConfigurations.remembrance.config.system.activationScripts.bootstrapPasswordHash.text`
   before/after and show it is identical (non-empty validator).
3. Remove the test-only bootstrap-hash seed fixture from `tests/iso-autostart-vm.nix` (keep the
   memory/cores overrides) so the VM test boots the config AS SHIPPED; keep every other assertion.

## Verification (capture everything; disk has ~290G free)
- (a) `timeout 3000 nix build .#checks.x86_64-linux.iso-autostart-vm --no-link` => rc=0 with the
  seed fixture removed (both variants assert as before).
- (b) `timeout 3600 nix build .#iso.antagony --no-link --print-out-paths` => rc=0 (the rebuild
  takes ~50 min), then BOOT THE ISO in QEMU with a serial console (use F-A's repro as a template;
  `-cdrom <iso> -boot d -m 2048 -nographic -no-reboot` plus serial console, KVM if available) and
  observe the boot reach multi-user (a login prompt / `Reached target Multi-User`) with NO
  `bootstrap password hash validation failed` and NO emergency mode. Capture the decisive lines.
- (c) `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'` => PASS.
- (d) Failure probe (scratch copy only): with the neutralization removed, the VM test's plainBoot
  fails the way the real ISO did - capture it.
- `git show --stat HEAD` = only your files; `bash -n`/parse checks on changed files.

## Commit
Exact message: `fix(iso): let the installer medium boot without the password validator`
(files: modules/flake/iso-images.nix, tests/iso-autostart-vm.nix).

## Evidence
`/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-16-thinkpad-zero-touch-install.log`

## DoneClaim (end your message with it)
`DoneClaim: {"task": "16: ISO medium boots", "changed_files": [...], "tests": ["<cmd> => <result>"], "manual_qa": ["<boot serial log path>"], "cleanup": ["..."], "risks": [...]}`

## Adversarial probes (record each)
- misleading_success_output: the boot must REACH MULTI-USER - "no failure lines" is not proof; quote the login prompt/multi-user line.
- stale_state: the rebuilt ISO must reflect the fix (boot the newly built artifact, not a cached path).
- dirty_worktree: `git show --stat HEAD` = only the two files.
- hung_or_long_commands: all builds/boots under the stated timeouts.
- flaky_tests: the VM test run must be deterministic; re-run once if it is cheap.
