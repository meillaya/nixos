# F-A ISO build attempts (running record)

Goal: build `.#iso.antagony` at commit a1c86ad (later 5d4052f) and boot it in QEMU to test
whether the real ISO boots as shipped or aborts at the bootstrapPasswordHash activation.

| # | Started | Outcome | Reason |
|---|---------|---------|--------|
| 1 | ~14:53 | killed by orchestrator | root fs hit 60M free during mksquashfs; desktop at risk |
| 2 | ~15:34 | BUILD_RC=1 after 41m30s | xorriso: image 5761080 sectors (10.99 GiB) > free 2919686 sectors (5.57 GiB) |
| 3 | ~15:40 | BUILD_RC=1 after 35m | xorriso: image 5761080s (10.99 GiB) > free 5205942s (9.93 GiB) — short by ~1.1 GiB; `nix store gc --max 25g` had freed 6.3 GiB but that is not enough |

Mechanism evidence (source-verified): `modules/nixos/bootstrap-password.nix` installs
`system.activationScripts.bootstrapPasswordHash` with no variant gate; a fresh boot with no
`/var/lib/nixos-bootstrap/mei-password.hash` and a locked account fails activation, which the
todo-14 VM test observed aborting switch-root before /etc lands. The real ISO boots the same
config's initrd/activation.

## Verdict: UNVERIFIABLE-DISK (2026-10-06)

The machine cannot assemble this ISO: the single `isoImage` derivation holds a ~10 GiB squashfs
temp while xorriso writes an 10.99 GiB ISO, so the build needs ~21 GiB free at start and
>= 11 GiB free at the xorriso stage. Best observed: 9.93 GiB (attempt 3, after a full bounded
gc). Two independent xorriso failures (attempts 2 and 3) show the same shortfall; attempt 1 was
killed during a disk emergency. Remedy: free >= ~3 GiB more (e.g. `sudo nix-collect-garbage -d`
for old system generations) and re-run `nix build .#iso.antagony` + the QEMU boot test in
/tmp/iso-diag (boot.sh is staged there).

Mechanism evidence stands: the activation validator has no variant gate and aborts a fresh
boot pre-switch-root (observed in the todo-14 VM test); the real ISO boots the same
initrd/activation, so the ISO is very likely unbootable as shipped — but the real-medium boot
remains UNVERIFIED.

## Retry note (2026-10-06, later)

After attempt 3's temp cleanup the root fs sits at 23 GiB free — about 2 GiB above the
worst-case need (squashfs temp ~10 GiB + ISO 10.99 GiB). A fourth attempt is therefore
scheduled AFTER the wave-3 verification (which needs a few GiB itself), to avoid concurrent
disk contention. The verdict above (UNVERIFIABLE-DISK) applies to attempts 1-3; attempt 4
may supersede it.
