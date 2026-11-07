# The personal distro

The distro is a separate flake under `distro/`. It owns one live ISO and one
prebuilt installed system. Both are built from the real workstation profile,
`nixosConfigurations.remembrance`, with the live and installed overrides in
`distro/modules/`.

## Profiles

`distro/flake.nix` extends the fleet host configuration:

- `nixosConfigurations.installed` adds `distro/modules/base.nix` and
  `distro/modules/installed.nix`. The hostname, timezone, keyboard, kernel,
  Tailscale, Syncthing, SSH trust, and Home Manager payload come from the
  `remembrance` aspect. `base.nix` adds the distro identity and a mutable user
  so the installer can set a password. `installed.nix` keeps SSH enabled. The
  first boot is the named host.
- `nixosConfigurations.live` adds `base.nix` and `live.nix`. Live sets a tmpfs
  root, auto-logs in as `mei`, gives passwordless sudo, and turns off the
  personal SSH keys, Tailscale, Syncthing, and label mounts. It also pins the
  US locale and keyboard.
- `iso.live` extends the live configuration with `iso.nix`, `installer.nix`,
  the installed toplevel, and the main flake source. `installer.nix` adds the
  console installer, the Zenity wrapper, and a Niri `spawn-at-startup` line, so
  the graphical installer opens in the live session.

The installed closure is the workstation profile, not a second distro role.
The distro pins the same nixpkgs revision as the fleet and follows it through
the `nixos-config` input.

## Storage contract

The installer writes:

- GPT partition 1: 1 GiB, type `EF00`, partlabel `NIXBOOT`, FAT32 label
  `NIXBOOT`;
- GPT partition 2: remainder, type `8300`, partlabel `NIXROOT`, Btrfs label
  `NIXROOT`;
- Btrfs subvolumes `@root`, `@home`, `@nix`, `@log`.

The installed closure mounts those labels. It has no disk ID, UUID, or disko
evaluation. A disk with the labels boots the same closure, which is what makes
the installer disk-agnostic. The live profile turns the mount set off with
`my.storage.labels.enable = false`.

## Build and install

From the repository root:

```bash
nix build ./distro#iso.live
```

Write the ISO to a USB stick, or copy it to a Ventoy data partition. Boot the
medium with UEFI. After Niri starts, `nixos-install-gui` opens.

The graphical flow lists the eligible internal disks, asks for the password,
confirms the erase, runs the installer, and offers a reboot. The console flow
is still available:

```bash
sudo nixos-install-tui
```

`distro/pkgs/distro-installer.nix` wraps `distro/scripts/install.py` and
supplies:

- `NIXOS_INSTALLED_SYSTEM`: the prebuilt installed toplevel;
- `NIXOS_FLAKE_SOURCE`: the main flake source copied to `/etc/nixos`;
- `NIXBOOT_LABEL` and `NIXROOT_LABEL`;
- `NIXOS_LIVE_USER`.

`distro/pkgs/distro-installer-gui.nix` wraps the console installer with Zenity.
The GUI collects a disk and a password, then calls the console installer with
`--disk`, `--yes`, `--non-interactive`, and `--password-file`.

The installer checks UEFI, then rejects read-only disks, the live medium,
disks below 16 GiB, USB transports, zram, and device-mapper devices. It creates
a 1 GiB ESP and a Btrfs root, mounts the subvolumes, runs
`nixos-install --system`, sets the password, copies the flake source, and
unmounts. No network is needed.

`nixos-install-tui --list-disks` prints the eligible disks as JSON and exits.
The GUI reads that same list. `--test` stops after the mounts. `--yes` skips
the typed confirmation; `--non-interactive` takes the password from
`--password-file` or `NIXOS_PASSWORD`.

## Checks

```bash
cd distro
nix flake check
nix build .#checks.x86_64-linux.installer-disk-vm
```

`distro/tests/config-eval.nix` checks the installed host identity, the live
overrides, the label contract, and the ISO contents. The VM test boots the live
profile, checks `--list-disks`, and runs the installer's disk phase against a
blank virtual disk.

## Rebuilds

The installer copies the main flake source to the target's `/etc/nixos`. Later
`nixos-rebuild switch --flake /etc/nixos#remembrance` runs use that source and
update the installed host. Rebuilds may fetch flake inputs; the install itself
does not.

## Non-goals

LUKS2, persistence/vaults, Secure Boot, public-release hardening, a generic
username, a curated package set, and the MeccanicOS extras (command bar, AI,
fleet, tutorial) are not part of this version.
