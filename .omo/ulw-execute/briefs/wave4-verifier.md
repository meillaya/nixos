# Wave-4 independent verifier — todo 16 (installer medium bootability)

You did not implement this work. Verify it adversarially; `confirmed` is the only pass verdict.
Sources of truth: the plan `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md` (todo 16),
the F-A diagnosis `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/F-A-iso-boot-diagnosis.md`,
and the worker's evidence `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-16-thinkpad-zero-touch-install.log`.

Worktree under verification: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave4` (branch `thinkpad-zero-touch-install/wave4`).
Record the tip; if it moves, verify at the current tip and report.

## What to verify
1. The fix is ISO-only: `modules/flake/iso-images.nix` neutralizes BOTH
   `system.activationScripts.bootstrapPasswordHash` and `consumeBootstrapPassword` inside the
   installer-variant extension only. Prove the INSTALLED system is untouched: eval
   `nixosConfigurations.remembrance.config.system.activationScripts.bootstrapPasswordHash.text`
   (and `.consumeBootstrapPassword.text`) at this tip and at main (`5d4052f`) and show identical
   non-empty validator text; eval the ISO config and show both scripts are empty.
2. The VM test now boots the config AS SHIPPED: the bootstrap-hash seed fixture is gone from
   `tests/iso-autostart-vm.nix`; re-run `timeout 3000 nix build .#checks.x86_64-linux.iso-autostart-vm --no-link`
   => rc=0 with both variants' assertions intact (plainBoot inert; gatedBoot gate opens, fails
   cleanly, rescue active, no marker, no disk write).
3. THE decisive medium proof: the REBUILT ISO boots. Re-boot the worker's ISO artifact in QEMU
   with a serial console yourself (or re-run the boot with a fresh qemu invocation) and quote the
   lines showing multi-user reached (login prompt / `Reached target Multi-User`) with NO
   `bootstrap password hash validation failed` and NO emergency mode. `stale_state`: boot the
   artifact built by THIS fix (check the store path/mtime), not a cached older ISO.
4. Failure falsifiability (scratch copy under /tmp): with the neutralization removed, the VM
   test's plainBoot fails the way the real ISO did (the old abort) — capture it.
5. `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'` => PASS;
   `git show --stat HEAD` = only the two files; tree clean at the end.

## Output
Write `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/wave4-verification.json`:
`{"verified_tip": "...", "verdict": "confirmed|false-positive|needs-fix|needs-human-review", "evidence": [...], "repro": "...", "confidence": 0.0, "adversarial": {...}, "cleanup": [...]}`
and include the verdict + evidence in your final message.

## Rules
- Read-only on the worktree; scratch only under /tmp with cleanup receipts.
- Disk is ample (~290G); wrap long builds/boots in timeouts; never nix store gc.
