# F-A — does the REAL ISO (`nix build .#iso.antagony`) boot? (report-only)

**Verdict: UNBOOTABLE.** The real ISO, built as shipped and booted fresh in qemu, aborts at
the `bootstrapPasswordHash` activation and never reaches multi-user — exactly the mechanism the
todo-14 VM test observed and compensated for with an initrd seed fixture.

Investigated at commit `a1c86ad` (branch `thinkpad-zero-touch-install/wave3`), worktree
`/tmp/iso-diag` (removed after).

## Decisive boot lines (real ISO, serial console)

```
[  OK  ] Reached target Switch Root.
         Starting NixOS Activation...
Oct 06 21:14:21 antagony initrd-nixos-activation-start[176]: booting system configuration /nix/store/ddy21llcihhqbrrrcq8n5pbvj3f8bj26-nixos-system-antagony-26.11.20260923.4975466
Oct 06 21:14:21 antagony initrd-nixos-activation-start[176]: running activation script...
Oct 06 21:14:22 antagony initrd-nixos-activation-start[199]: bootstrap password hash validation failed: missing /var/lib/nixos-bootstrap/mei-password.hash
Oct 06 21:14:22 antagony systemd[1]: initrd-nixos-activation.service: Deactivated successfully.
Oct 06 21:14:22 antagony systemd[1]: Finished NixOS Activation.
         Starting Switch Root...
Oct 06 21:14:22 antagony @ystemctl[207]: Failed to switch root: Specified switch root path '/sysroot' does not seem to be an OS tree. os-release file is missing.
[FAILED] Failed to start Switch Root.
See 'systemctl status initrd-switch-root.service' for details.
You are in emergency mode. After logging in, type "journalctl -xb" to view
```

- `initrd-nixos-activation-start[199]: bootstrap password hash validation failed: missing
  /var/lib/nixos-bootstrap/mei-password.hash` — the failure.
- `Failed to switch root: Specified switch root path '/sysroot' does not seem to be an OS tree.
  os-release file is missing.` — the symptom: the activation aborts before `/etc` is populated,
  so `/sysroot` is not a valid OS tree and switch-root refuses.
- `You are in emergency mode.` — the boot ends here; no `Reached target Multi-User`, no login.

Raw serial log: `F-A-serial-boot.log`. Build log (BUILD_RC=0): `F-A-build-attempt4.log`.

## Mechanism (why the shipped ISO cannot boot)

`flake.iso.<host>` = `flake.isoConfig.<host>.config.system.build.images.iso`, and
`isoConfigFor` = `nixosConfigurations.<host>.extendModules { optional boot.initrd.enable =
lib.mkForce true (when machine.boot.state == "disabled"); ++ [ enrollment installerMarker
btrfsSupport autoinstall ] }` (`modules/flake/iso-images.nix`). `antagony.boot.state ==
"disabled"`, so the ISO forces `boot.initrd.enable = true`; `boot.initrd.systemd.enable = true`
is the nixpkgs 26.11 default. The resulting config therefore exposes

- `boot.initrd.systemd.services.initrd-nixos-activation`, and
- `system.activationScripts.bootstrapPasswordHash` with `users.deps = [ "bootstrapPasswordHash" ]`.

In nixpkgs `nixos/modules/system/boot/systemd/initrd.nix:774-807`, `initrd-nixos-activation.service`
runs `exec chroot /sysroot "$closure/prepare-root"` — the stage-2 init that runs **all**
`system.activationScripts` **before** switch-root. Meanwhile `nixos/modules/installer/cd-dvd/
iso-image.nix` (via `config.lib.isoFileSystems`) makes the live ISO's `"/"` a fresh **tmpfs**:

```
"/"             = tmpfs
"/iso"          = iso9660 (the CD, by volume label)
"/nix/.ro-store"= squashfs /sysroot/iso/nix-store.squashfs (loop)
"/nix/store"    = overlay(ro-store + rw-store tmpfs)
```

So at activation time `/var` is an empty tmpfs: `/var/lib/nixos-bootstrap/mei-password.hash`
does not exist, and there is no unlocked `/etc/shadow` password. `bootstrap-password.nix`'s
validator calls `fail "missing $hash_file"` and exits 1. The activation aborts before writing
`/etc`, switch-root rejects `/sysroot` (no `os-release`), and the boot lands in emergency mode.

## What the ISO does differently from the todo-14 test harness

Nothing functional — the test boots the *same* extended config. The test **compensates** with a
test-only fixture (`tests/iso-autostart-vm.nix`): `boot.initrd.systemd.services.seed-bootstrap-password`
installs a throwaway yescrypt hash into `/sysroot/var/lib/nixos-bootstrap/mei-password.hash`
before `initrd-nixos-activation.service`, so the validator passes. The real ISO ships no such
fixture, so it aborts. The test's own comment documents this: "the ISO config's activation
validator … fails any fresh machine without … mei-password.hash, and the config's systemd initrd
runs activation before switch-root, so a fresh boot never reaches stage 2 (observed: switch-root
fails with 'os-release file is missing')".

## Reproduction

Build (succeeded on the 4th attempt once free space was ample; the ISO is ~11 GiB and the
39 363 840 KiB squashfs lands in the build temp on `/`):

```
git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3 worktree add --detach /tmp/iso-diag a1c86ad
cd /tmp/iso-diag
timeout 3000 nix build .#iso.antagony --no-link --print-out-paths
# -> /nix/store/wpjgp9cn6jzdslw8fiq56sv1rs5nqnij-nixos-26.11.20260923.4975466-x86_64-linux.iso
```

Boot (kernel + initrd + `console=ttyS0` from the ISO's own `boot-serial` entry, CD attached):

```
qemu-system-x86_64 -m 2048 -smp 2 -no-reboot -nographic -monitor none \
  -kernel /nix/store/3znssfyqj0a29cyngp5n0309cparnmpc-linux-7.2.7/bzImage \
  -initrd /nix/store/blzcihisk86k7wr2337gj8wqng0lpym4-initrd-linux-7.2.7/initrd \
  -append "init=/nix/store/ddy21llcihhqbrrrcq8n5pbvj3f8bj26-nixos-system-antagony-26.11.20260923.4975466/init root=fstab loglevel=4 lsm=landlock,yama,bpf console=ttyS0,115200n8" \
  -cdrom /nix/store/wpjgp9cn6jzdslw8fiq56sv1rs5nqnij-nixos-26.11.20260923.4975466-x86_64-linux.iso/iso/nixos-26.11.20260923.4975466-x86_64-linux.iso \
  -enable-kvm -cpu host
```

At the emergency prompt, the guest journal confirms the cause:

```
bash-5.3# journalctl -b -u initrd-nixos-activation.service --no-pager --full
… initrd-nixos-activation-start[199]: bootstrap password hash validation failed: missing /var/lib/nixos-bootstrap/mei-password.hash
```

## Build attempts (environment, not a product defect)

| # | Result | Reason |
|---|--------|--------|
| 1 | killed by orchestrator | disk hit 60 MiB free during `mksquashfs` (desktop at risk) |
| 2 | BUILD_RC=1 | `xorriso : FAILURE : Image size 5761080s exceeds free space on media 2919686s` (10.99 GiB image vs 5.57 GiB free) |
| 3 | BUILD_RC=1 | same xorriso failure: image 5761080s vs free 5205942s (9.93 GiB) — short ~1.06 GiB |
| 4 | **BUILD_RC=0** | after reclaiming ~6 GiB of re-downloadable tool caches; ISO 11 798 691 840 bytes |

The build temp (`nix-store.squashfs`, ~11 GiB) is written on `/` and cannot be relocated without
root (`--option build-dir` under `/tmp` or `/dev/shm` is rejected by nix as world-writable;
`/run/user/$UID` is only 3.1 GiB).

## Cleanup receipts

- qemu killed (pid tree terminated); serial/boot logs archived here.
- `/tmp/iso-diag` worktree removed: `git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3 worktree remove --force /tmp/iso-diag`.
- scratch dir `/tmp/iso-diag-work` deleted.
- wave-3 worktree `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` left clean (no edits by this worker).
- side effect disclosed: reclaimed re-downloadable caches `~/.cache/nix` (522 MiB), `~/.cache/uv`
  (1.8 GiB), `~/.cache/bun` (2.8 GiB) to gain build headroom. No `nix store gc` was run.

FADiagnosis: {"verdict": "UNBOOTABLE", "decisive_lines": ["initrd-nixos-activation-start[199]: bootstrap password hash validation failed: missing /var/lib/nixos-bootstrap/mei-password.hash", "systemd[1]: Finished NixOS Activation.", "@ystemctl[207]: Failed to switch root: Specified switch root path '/sysroot' does not seem to be an OS tree. os-release file is missing.", "[FAILED] Failed to start Switch Root.", "You are in emergency mode. After logging in, type \"journalctl -xb\" to view"], "repro": "git worktree add --detach /tmp/iso-diag a1c86ad; cd /tmp/iso-diag; nix build .#iso.antagony --no-link --print-out-paths; qemu-system-x86_64 -m 2048 -smp 2 -no-reboot -nographic -monitor none -kernel /nix/store/3znssfyqj0a29cyngp5n0309cparnmpc-linux-7.2.7/bzImage -initrd /nix/store/blzcihisk86k7wr2337gj8wqng0lpym4-initrd-linux-7.2.7/initrd -append 'init=/nix/store/ddy21llcihhqbrrrcq8n5pbvj3f8bj26-nixos-system-antagony-26.11.20260923.4975466/init root=fstab loglevel=4 lsm=landlock,yama,bpf console=ttyS0,115200n8' -cdrom /nix/store/wpjgp9cn6jzdslw8fiq56sv1rs5nqnij-nixos-26.11.20260923.4975466-x86_64-linux.iso/iso/nixos-26.11.20260923.4975466-x86_64-linux.iso -enable-kvm -cpu host", "cleanup": ["qemu killed", "git worktree remove --force /tmp/iso-diag", "rm -rf /tmp/iso-diag-work", "wave-3 worktree clean", "reclaimed ~/.cache/{nix,uv,bun} (no store gc)"]}
