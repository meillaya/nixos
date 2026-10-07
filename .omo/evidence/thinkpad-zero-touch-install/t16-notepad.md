# Ultrawork Notepad — todo 16: make the installer medium boot (fix F-A)
Worktree: /home/mei/nixos-wt/thinkpad-zero-touch-install-wave4 (branch thinkpad-zero-touch-install/wave4, off main 5d4052f)
Tier: LIGHT — single-spot ISO-only module addition following the existing extendModules pattern; no open design decisions. Reviewer gate: plan file exists but tier=LIGHT -> self-review.

## Post-reboot resume (machine rebooted ~18:20 during first ISO build's xorriso stage)
- Edits SURVIVED: git status --porcelain = M modules/flake/iso-images.nix, M tests/iso-autostart-vm.nix (verified by git diff).
- /tmp scratch (old notepad, probe worktree /tmp/t16-probe, old harness) GONE.
- Evidence in .omo SURVIVED: t16-vmcheck.log+testlog.txt, t16-probe-vmcheck.log+testlog.txt, t16-iso-build.log (partial).
- Re-did: pruned stale probe worktree; recreated /tmp/t16-boot.sh; re-ran (a) VM check rc=0 (cached), (c) config-eval PASS, eval-wall (base sha=28e93224f86aa800 len=3375 nonempty; ISO both scripts empty); relaunched ISO build as bash_1.

## Required fix
iso-images.nix: installer-only module bootstrapPasswordInert, lib.mkForce { deps=[]; text=""; } for system.activationScripts.bootstrapPasswordHash AND consumeBootstrapPassword; added to extendModules list.
tests/iso-autostart-vm.nix: removed bootstrapHash + seed-bootstrap-password fixture; kept memory/cores overrides; comments updated.

## Success criteria + QA scenarios (evidence)
(a) nix build .#checks.x86_64-linux.iso-autostart-vm --no-link => BUILD_RC=0 (seed removed). Evidence: t16-vmcheck.log + t16-vmcheck-testlog.txt (plainBoot "Reached target Multi-User System" @51.7s; gatedBoot @50.1s; zero "bootstrap password hash validation failed"; only harmless nixpkgs mutableUsers warning). PASS.
(b) nix build .#iso.antagony --no-link --print-out-paths => rc=0; QEMU boot (F-A template, serial console) reaches multi-user, NO validator failure, NO emergency mode. Evidence: t16-iso-build.log + t16-iso-serial-<tag>.log. PENDING (re-running).
(c) nix-instantiate --eval --strict tests/dendritic-config-eval.nix => PASS. Evidence: t16-config-eval.log. PASS.
(d) failure probe: scratch copy (detached worktree at HEAD + fixture-removed test, NO neutralization) => PROBE_BUILD_RC=1; both variants: "bootstrap password hash validation failed: missing ...mei-password.hash" -> "Failed to switch root: ... os-release file is missing." -> "Reached target Emergency Mode." Evidence: t16-probe-vmcheck.log + t16-probe-testlog.txt. PASS (probe worktree pruned after).
Non-ISO unchanged: remembrance bootstrapPasswordHash.text sha=28e93224f86aa800 len=3375 identical worktree vs main (pre-reboot both trees; post-reboot worktree text re-captured identical). PASS.
Static: nix-instantiate --parse both files OK; dendritic-architecture/boundaries/apps=PASS (pre-reboot).

## Findings
- F-A: initrd-nixos-activation runs ALL activation scripts pre-switch-root; live ISO / is tmpfs -> bootstrapPasswordHash fails "missing /var/lib/nixos-bootstrap/mei-password.hash" -> switch-root "os-release file is missing" -> emergency mode.
- bootstrap-password.nix sets bootstrapPasswordHash + consumeBootstrapPassword (both hard-fail on absent hash file), plus users.deps=[bootstrapPasswordHash].
- nixpkgs update-users-groups.pl:241-247: mutableUsers + missing hashedPasswordFile => warn only, no fail => no third neutralization needed.
- Live-ISO serial boot: use F-A template (kernel+initrd+system from isoConfig.antagony, -cdrom the built ISO, console=ttyS0).

## Now
Waiting on bash_1 ISO build (re-run post-reboot). Then boot newly built artifact.

## Todo
- [x] Recon, edits, static/eval checks, (a),(c),(d), non-ISO unchanged
- [ ] (b) ISO build rc=0
- [ ] (b) QEMU serial boot -> multi-user
- [ ] cleanups
- [ ] evidence file task-16-*.log
- [ ] commit fix(iso): let the installer medium boot without the password validator
- [ ] DoneClaim


### [2026-10-06T22:57:28.451Z] COMPLETE — todo 16 verified + committed
- (b) ISO rebuild: BUILD_RC=0 -> /nix/store/9bqrwpqybmvv400q806w7rvbq9z2j6y7-nixos-26.11.20260923.4975466-x86_64-linux.iso (distinct from F-A wpjgp9cn).
- (b) QEMU serial boot of the new artifact (paths from the new ISO's isolinux.cfg; system 0gwn2sk…, activate has 0 validators): "Reached target Multi-User System" + "antagony login:"; 0x validator failure, 0x Emergency Mode. Evidence t16-iso-serial-clean.log.
- boot harness note: qemu is not on PATH; use /nix/store/y5lw20ymidqg7x3q6f23vkf734id7fmr-qemu-11.1.1/bin/qemu-system-x86_64; `-nographic` produced NO serial output (guest appeared idle) -> `-display none -serial file:` works.
- Commit 7689b0c "fix(iso): let the installer medium boot without the password validator"; git show --stat HEAD = only the two files.
- Evidence: /home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-16-thinkpad-zero-touch-install.log
- Cleanup: qemu NONE, /tmp/t16* none, worktree clean, monitors killed, probe worktree pruned.

## Learnings
- Live-ISO serial boot via -kernel/-initrd/-append is the reliable channel; -nographic/sw stdio silently yields an idle guest.
- isoConfig.<host>.config.system.build.toplevel does NOT evaluate (fileSystems assertion) — the ISO's own isolinux.cfg is the source of truth for kernel/initrd/system paths.
