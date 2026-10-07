# Installer ISO: rebuild it, test it in QEMU, boot a real machine

This note covers the per-host installer ISO only: where the built file is, how to
rebuild it, how to check in QEMU that it boots, and how to use it on a real machine.

The install flows themselves (the one-command app, the operator path, secrets, the
four-enrollment gate) are in
[`nixos-anywhere-iso-install.md`](./nixos-anywhere-iso-install.md) and
[`new-machine-ssh-install.md`](./new-machine-ssh-install.md).

## Quick reference

| I want to | Run |
| --- | --- |
| build the ISO | `nix build .#iso.antagony` (or `.remembrance`) |
| check only the config | `nix build --dry-run .#iso.antagony` |
| check it boots, no ISO build | `nix build .#checks.x86_64-linux.iso-autostart-vm` |
| write a USB stick | `sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M oflag=sync` |

## Where the file is

`nix build .#iso.<host>` writes `result/iso/nixos-<label>-x86_64-linux.iso`. The
`result` symlink is a garbage-collector root, so the store keeps the file.

A build run with `--no-link` has no root. The file then exists only in the store:

```
/nix/store/<hash>-nixos-<label>-x86_64-linux.iso/iso/nixos-<label>-x86_64-linux.iso
```

`nix store gc` will delete it, so copy it out first.

Builds from 2026-10-06 (repo at `11f544a`):

- working: `/nix/store/9bqrwpqybmvv400q806w7rvbq9z2j6y7-nixos-26.11.20260923.4975466-x86_64-linux.iso/iso/nixos-26.11.20260923.4975466-x86_64-linux.iso`
- old and broken (pre-fix): `/nix/store/wpjgp9cn6jzdslw8fiq56sv1rs5nqnij-...`; safe to delete

The hash depends on the exact tree. Uncommitted changes, even to a tracked file such
as `.direnv/flake-profile`, produce a different path. Use `result/iso/` rather than a
hardcoded hash.

## Rebuild

```bash
nix build .#iso.antagony          # or .#iso.remembrance
ls result/iso/
```

- A cold build needs about 21 GB free and 45 to 60 minutes. The derivation holds a
  ~10 GB squashfs temporary file while xorriso writes the ~11 GB ISO, both on the same
  filesystem. With less free space, xorriso fails with
  `Image size ... exceeds free space on media`. Free space and re-run: the store keeps
  everything else, so only squashfs and xorriso repeat (30 to 45 minutes).
- Config-only checks, no build:
  ```bash
  nix build --dry-run .#iso.antagony
  nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'
  ```

## Test the ISO in QEMU

The ISO boots the host's full configuration as a live medium, so a local boot proves it
reaches a login prompt. No target disk is needed.

### 1. Collect the kernel, initrd and init

```bash
KERNEL=$(nix eval --raw .#isoConfig.antagony.config.system.build.kernel)        # has bzImage
INITRD=$(nix eval --raw .#isoConfig.antagony.config.system.build.initialRamdisk) # has initrd
```

The ISO's own boot entry shows the same files plus the `init=` value:

```bash
xorriso -osirrox on -indev result/iso/*.iso \
  -extract /isolinux/isolinux.cfg /tmp/isolinux.cfg
grep -E 'LINUX|INITRD|APPEND' /tmp/isolinux.cfg | tail -3
```

The last entry is `boot-serial`; it adds `console=ttyS0`, which is what makes the QEMU
log readable.

### 2. Boot it

```bash
ISO=$(ls result/iso/*.iso)                      # or an explicit /nix/store/... path
SYSTEM=<the init= path from step 1, without the trailing /init>

nix shell nixpkgs#qemu -c qemu-system-x86_64 \
  -m 4096 -smp 2 -no-reboot \
  -kernel "$KERNEL/bzImage" \
  -initrd "$INITRD/initrd" \
  -append "init=$SYSTEM/init root=fstab loglevel=4 lsm=landlock,yama,bpf console=ttyS0,115200n8" \
  -cdrom "$ISO" \
  -display none -serial file:/tmp/iso-boot.log
```

- `qemu-system-x86_64` is not on the host `PATH`; `nix shell nixpkgs#qemu` provides it.
- `-display none -serial file:` is the reliable way to capture output. `-nographic` can
  leave the guest silent.
- Booting the CD by itself (`-cdrom ... -boot d`, no `-kernel`) is silent from the
  kernel onward: the default menu entry has no `console=ttyS0`. That is why the kernel
  and initrd are passed explicitly, mirroring the `boot-serial` entry.
- Add `-enable-kvm -cpu host` when `/dev/kvm` is usable; without it QEMU still boots, slower.
- Run it under `timeout 600` or similar. The guest writes to the log file, not stdout.

### 3. Check the result

```bash
grep -a 'Reached target Multi-User System' /tmp/iso-boot.log | head -1
grep -a 'login:' /tmp/iso-boot.log | head -1
```

Both lines present means the medium boots. There must be no
`bootstrap password hash validation failed` and no `Emergency Mode`.

- systemd mixes ANSI colour codes into those lines. `grep -a` copes; for exact counts,
  strip colours first: `sed -r 's/\x1B\[[0-9;]*[mK]//g'`.
- An ISO built before commit `7689b0c` fails instead, with
  `bootstrap password hash validation failed: missing /var/lib/nixos-bootstrap/mei-password.hash`,
  then `Failed to switch root: ... os-release file is missing`, then emergency mode. That
  means the installer-only fix in `modules/flake/iso-images.nix` is missing or overridden.

### 4. Try the opt-in installer (optional)

Append `nixos.autoinstall=1` to the kernel command line. The unit starts, refuses the
machine (a VM is not the ThinkPad, so the DMI and disk checks fail), and drops into
`iso-install-rescue.target`, a root shell on tty1. No disk is written.

Keep the flag out of `boot.kernelParams`. It is a per-boot choice, made at the boot menu.

### 5. Or run the repo's own check

```bash
nix build .#checks.x86_64-linux.iso-autostart-vm
```

It boots the config twice in one run: a plain boot stays inert, a gated boot reaches the
rescue target. It fails if the installer-only fix above is removed.

## Boot a real machine

```bash
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

With a Ventoy stick, skip `dd`: drop the ISO on its data partition and pick it from the
Ventoy menu. Either way, verify the copy before booting it:

```bash
sha256sum result/iso/*.iso \
  "/run/media/$USER/Ventoy/nixos-26.11.20260923.4975466-x86_64-linux-antagony-installer.iso"
```

Both hashes must match.

- Write the whole device, then boot UEFI. The image is hybrid (isolinux and EFI), with
  `secureBoot = false`.
- 4 GB RAM or more. The live medium runs from RAM; the target disk stays untouched until
  the install starts.
- Bring the network up first (`nmtui` for Wi-Fi). `ip a` prints the address the operator
  path needs.

Then pick one:

- One command on the target:
  ```bash
  sudo nix run --extra-experimental-features 'nix-command flakes' \
    github:meillaya/nixos#install -- --yes
  ```
  It detects the machine, enrolls it, prints a one-time password for `mei`, stages the
  enrollment files and the age identity into the new system, and installs over
  `root@127.0.0.1`.
- From another machine: `bin/host-install.sh --target-host <ip> --yes`. The ISO runs
  sshd and accepts the repo's root key.
- At the boot menu, append `nixos.autoinstall=1` to let the medium install by itself. It
  requires the host and disk to match before writing anything, reboots on success, and
  drops to the rescue shell on failure.

Before any real install: back up `~/.config/sops/age/keys.txt` and
`secrets/remembrance-keys.yaml`. If the age identity exists only on the disk being
replaced, pass `--rescue-identity`. Details:
[`nixos-anywhere-iso-install.md`](./nixos-anywhere-iso-install.md),
[`new-machine-ssh-install.md`](./new-machine-ssh-install.md).

## Things that go wrong

- Not enough disk. xorriso's `exceeds free space on media` is about free space, not the config.
- A reboot during a build loses the temporary file. Re-run; the store is kept.
- A `--no-link` build can be garbage collected. Link or copy it.
- Uncommitted changes change the ISO store path.
- VM targets (Proxmox, libvirt): whole disk, UEFI firmware, 4 GB RAM.
