# The personal distro

The distro is one live ISO and one prebuilt installed system. It is personal:
the user is `mei`, the package set is the repository's existing desktop, and
the installed hostname is `nixos`.

## Profiles

`nixosConfigurations.live` is a normal live system. It includes `distro-role`,
`modules/distro/base.nix`, and `modules/distro/live.nix`:

- user `mei`, empty initial password, passwordless sudo;
- auto-login into the Niri session;
- no personal SSH keys, tailscale, or syncthing;
- a Btrfs/VFAT-capable kernel and generic x86 firmware, microcode, audio,
  Bluetooth, power, i2c, and suspend support.

`nixosConfigurations.installed` includes the same desktop, the label storage
module, and `modules/distro/installed.nix`. It enables SSH but trusts no key,
uses mutable users, and has no password until the installer sets one.

## Storage contract

The installer writes:

- GPT partition 1: 1 GiB, type `EF00`, partlabel `NIXBOOT`, FAT32 label
  `NIXBOOT`;
- GPT partition 2: remainder, type `8300`, partlabel `NIXROOT`, Btrfs label
  `NIXROOT`;
- Btrfs subvolumes `@root`, `@home`, `@nix`, `@log`.

The installed closure mounts those labels. It has no disk ID, UUID, or disko
evaluation. A disk with the labels boots the same closure, which is what makes
the installer disk-agnostic.

## ISO

`flake.iso.live` extends `nixosConfigurations.live` with
`modules/distro/iso.nix`, `modules/distro/installer.nix`, the prebuilt installed
toplevel, and the flake source. `isoImage.storeContents` carries the installed
closure, so `nixos-install --system` needs no network.

The ISO uses the live user session, not an XFCE installer desktop. Open a
terminal in the live session and run `sudo nixos-install-tui`, or run
`nixos-install-tui --test --disk /dev/sdX` to exercise the disk steps alone.

## Installer

`scripts/distro/install.py` is the disk and install driver. The wrapper
`nixos-install-tui` supplies:

- `NIXOS_INSTALLED_SYSTEM`: the prebuilt installed toplevel;
- `NIXOS_FLAKE_SOURCE`: the flake source copied to `/etc/nixos`;
- `NIXBOOT_LABEL` and `NIXROOT_LABEL`;
- `NIXOS_LIVE_USER`.

The flow is UEFI check, disk selection, typed confirmation, GPT and filesystem
creation, subvolume mounts, `nixos-install --system`, password creation,
`/etc/nixos` copy, and unmount. `--test` stops after the mounts. `--yes` skips
the typed confirmation; `--non-interactive` requires `--disk` and
`NIXOS_PASSWORD`.

## Rebuilds

The installer copies the flake source to the target's `/etc/nixos`. A later
`nixos-rebuild switch --flake /etc/nixos#installed` uses that source. Rebuilds
may fetch flake inputs; the install itself does not.

## Non-goals

LUKS2, persistence/vaults, Secure Boot, public-release hardening, a generic
username, a curated package set, and the MeccanicOS extras (command bar, AI,
fleet, tutorial) are not part of this version.
