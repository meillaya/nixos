# Build and test the live ISO

The ISO and the installer are x86_64-linux only. Build on a Linux host with
enough free space; a cold build holds a multi-GB squashfs and the installed
closure in the store.

## Build

```bash
nix build .#iso.live
ls result/iso/
```

`result` is a garbage-collector root. A `--no-link` build leaves the ISO in the
store without a root, so copy it out before the next collection.

## Static checks

```bash
nix flake check --all-systems --no-build
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-config-eval.nix
nix build .#checks.x86_64-linux.installer-disk-vm
```

The VM test boots the live profile with an extra blank disk and runs
`nixos-install-tui --test`. It checks the `NIXBOOT` and `NIXROOT` labels, the
four subvolumes, and the mount/unmount path. It does not install a system.

## Manual install

Write the ISO as a raw image, boot UEFI, and run the installer from the live
session:

```bash
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

The installer rejects the live medium, read-only devices, disks smaller than
16 GiB, and BIOS boot. It prints the selected disk and requires `YES` before
erasing.

After the install, remove the ISO and reboot. The installed system mounts
`NIXBOOT` and `NIXROOT`, so the same closure works from any disk the installer
prepared.

## Migration

Existing NixOS hosts use the same labels. Relabel the root and ESP once before
switching:

```bash
sudo btrfs filesystem label / NIXROOT
boot_dev=$(findmnt -no SOURCE /boot)
sudo umount /boot
sudo fatlabel "$boot_dev" NIXBOOT
sudo mount /boot
```

Then `nixos-rebuild switch --flake .#remembrance`. Old generations keep their
original UUIDs and remain bootable.

## Failures

- `No space left on device` during a build means the store volume is full, not
  the configuration.
- A target without the labels drops to emergency mode; relabel it or install
  from the ISO.
- Two disks with `NIXROOT` make the boot ambiguous. Keep one system disk per
  machine.
