# Build and test the live ISO

The ISO and the installer are x86_64-linux only. Build on a Linux host with
enough free space; a cold build holds a multi-GB squashfs and the installed
closure in the store.

## Build

```bash
nix build ./distro#iso.live
ls result/iso/
```

`result` is a garbage-collector root. A `--no-link` build leaves the ISO in the
store without a root, so copy it out before the next collection.

The ISO is built from the real `remembrance` workstation profile. The distro
flake extends that configuration; it does not carry a second desktop role.

## Static checks

```bash
nix flake check --all-systems --no-build
cd distro
nix flake check
nix build .#checks.x86_64-linux.installer-disk-vm
```

The VM test boots the live profile with an extra blank disk. It checks that
`nixos-install-tui --list-disks` finds the blank disk and not the live root,
then runs `nixos-install-tui --test`. The test checks the `NIXBOOT` and
`NIXROOT` labels, the four subvolumes, and the mount/unmount path. It does not
install a system.

## Manual install

Copy the ISO to a Ventoy data partition, or write it as a raw image:

```bash
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot the medium with UEFI. After Niri starts, `nixos-install-gui` opens. It
lists the eligible internal disks, asks for the password, confirms the erase,
runs the installer, and offers a reboot. The console flow is available from a
terminal:

```bash
sudo nixos-install-tui
```

The installer rejects the live medium, read-only devices, disks smaller than
16 GiB, USB transports, zram, and device-mapper devices. It prints the selected
disk and requires a typed `YES` before erasing.

After the install, remove the ISO and reboot. The installed system mounts
`NIXBOOT` and `NIXROOT`, and the first boot is `remembrance` with the password
set during the install.

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
- The graphical installer does not open: run `nixos-install-gui` from a
  terminal, or use `sudo nixos-install-tui`.
- The desktop does not start: choose **Options > Disable display-manager** in
  the ISO boot menu, log in as `mei` with an empty password, and run the
  console installer.
