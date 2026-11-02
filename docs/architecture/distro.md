# The personal distro

The distro is a separate flake under `distro/`. It owns one live ISO and one
prebuilt installed system. Both are built from the real workstation profile,
`nixosConfigurations.remembrance`, with the live/installed overrides in
`distro/modules/`.

## Profiles

`distro/flake.nix` extends the fleet host configuration:

- `nixosConfigurations.installed` adds `distro/modules/base.nix` and
  `distro/modules/installed.nix`. It keeps the real Niri/Noctalia desktop, the
  user payload, and the label storage contract, with a fixed `nixos` hostname,
  SSH enabled, no trusted key, and mutable users.
- `nixosConfigurations.live` adds `distro/modules/base.nix` and
  `distro/modules/live.nix`. It sets `my.storage.labels.enable = false`, uses a
  tmpfs root, auto-logs in as `mei`, gives passwordless sudo, and disables the
  personal SSH, tailscale, and syncthing settings.
- `iso.live` extends the live configuration with `distro/modules/iso.nix`,
  `distro/modules/installer.nix`, the installed toplevel, and the main flake
  source.

The installed closure is the workstation profile, not a second `distro-role`.
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
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot the medium with UEFI, open a terminal in the live session, and run:

```bash
sudo nixos-install-tui
```

`distro/pkgs/distro-installer.nix` wraps `distro/scripts/install.py` and
supplies:

- `NIXOS_INSTALLED_SYSTEM`: the prebuilt installed toplevel;
- `NIXOS_FLAKE_SOURCE`: the main flake source copied to `/etc/nixos`;
- `NIXBOOT_LABEL` and `NIXROOT_LABEL`;
- `NIXOS_LIVE_USER`.

The flow is UEFI check, disk selection, typed confirmation, GPT and filesystem
creation, subvolume mounts, `nixos-install --system`, password creation,
`/etc/nixos` copy, and unmount. `--test` stops after the mounts. `--yes` skips
the typed confirmation; `--non-interactive` requires `--disk` and
`NIXOS_PASSWORD`.

## Checks

```bash
cd distro
nix flake check
nix build .#checks.x86_64-linux.installer-disk-vm
```

`distro/tests/config-eval.nix` checks the live, installed, and ISO contracts.
`distro/tests/installer-disk-vm.nix` runs the installer's disk phase against a
blank virtual disk.

## Rebuilds

The installer copies the main flake source to the target's `/etc/nixos`. A
later `nixos-rebuild switch --flake /etc/nixos#remembrance` (or `#antagony`)
uses that source. The first switch targets the real host; the installed
`nixos` hostname is only the initial identity. Rebuilds may fetch flake inputs;
the install itself does not.

## Non-goals

LUKS2, persistence/vaults, Secure Boot, public-release hardening, a generic
username, a curated package set, and the MeccanicOS extras (command bar, AI,
fleet, tutorial) are not part of this version.
