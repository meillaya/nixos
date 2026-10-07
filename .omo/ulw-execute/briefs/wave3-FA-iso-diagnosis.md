# F-A diagnostic — does the REAL ISO boot? (verification only, no fixes)

T14's VM test found that booting the extended ISO config fresh aborts: the
`bootstrapPasswordHash` activation script (modules/nixos/bootstrap-password.nix, deps: none,
readable now) hard-fails when `/var/lib/nixos-bootstrap/mei-password.hash` is missing and the
target user has no unlocked /etc/shadow password — and the config's systemd initrd runs
activation before switch-root, so the boot aborts (`os-release file is missing`). The landed
test compensates with a documented initrd seed fixture. Open question: does the REAL ISO
(`nix build .#iso.antagony`) boot as shipped?

## Method (report only — do not fix anything)
1. Scratch worktree at the pinned commit so the wave-3 tree is never disturbed:
   `git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3 worktree add --detach /tmp/iso-diag a1c86ad` (verify with `git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3 log -1`).
2. `timeout 3000 nix build .#iso.antagony --no-link --print-out-paths` in /tmp/iso-diag.
   Watch disk (~5G free): on ENOSPC stop and report; do not gc.
3. Boot the ISO in qemu (TCG fine): give it 2048M RAM, serial console, and capture the full
   boot log for up to ~10 minutes. Example: `qemu-system-x86_64 -m 2048 -nographic
   -no-reboot -cdrom <iso>/iso/*.iso` (add `-enable-kvm` if /dev/kvm is usable).
4. Decide from the boot log:
   - BOOTS: reaches systemd multi-user (login prompt / `Reached target`), no activation failure.
   - UNBOOTABLE: aborts with `bootstrap password hash validation failed` /
     `os-release file is missing` / emergency mode before multi-user.
   - Record the exact decisive lines.
5. Also inspect the ISO's initrd/activation wiring to explain the result: does the ISO boot
   run `system.activationScripts` (via systemd-initrd or nixos-activation)? Compare with the
   test harness's boot path. `nix log`/store inspection is fine; document where you looked.
6. Cleanup: remove /tmp/iso-diag worktree (`git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3 worktree remove --force /tmp/iso-diag`),
   kill qemu, delete scratch files; give receipts.

## Output
Write `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/F-A-iso-boot-diagnosis.md` with the
verdict, the boot-log excerpts, the reproduction commands, and what the ISO does differently
from the test harness (if anything). End with:
`FADiagnosis: {"verdict": "BOOTS|UNBOOTABLE|INCONCLUSIVE", "decisive_lines": ["..."], "repro": "...", "cleanup": ["..."]}`
