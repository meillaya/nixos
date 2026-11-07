# nixos

One flake for four personal machines, plus a separate distro flake for the
personal live/install medium. Den owns the host and user entities; flake-parts
owns the fleet outputs.

## Hosts

- `remembrance`, `antagony`: NixOS x86_64 workstations.
- `entropy`: nix-darwin on Apple silicon.
- `massive`: standalone Home Manager plus a system-manager layer on CachyOS.
- `distro/`: the personal live ISO and installer. It extends the real
  `remembrance` workstation profile rather than duplicating a distro role.

Host identity lives in `modules/aspects/inventory.nix` as
`users.mei.identity`. There is no machine-authority record, intake document, or
per-host disk binding.

## Quickstart

```bash
nix run .#build                # build the current host, change nothing
nix run .#build-switch         # build and activate the current host
nix run .#nh -- os dry-build   # print the activation diff
```

`build` and `build-switch` infer the current hostname and refuse to fall back to
another host. `nix run .#update` refreshes the flake inputs and `nix run .#clean`
drops system generations older than seven days. `zix` is a developer tool:
`nix run .#zix -- --help`; it is not installed on the hosts.

The only configured shells are Nushell (the login shell) and Bash.

## Install the distro

Build the live ISO from the distro flake on an x86_64-linux machine, then write
it to a USB stick or copy it to a Ventoy data partition:

```bash
nix build ./distro#iso.live
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot the medium with UEFI. The live session opens the graphical installer,
which lists the eligible internal disks, asks for the password, and copies the
prebuilt installed system. The console installer is still available:

```bash
sudo nixos-install-tui
```

The installer accepts any whole internal disk of at least 16 GiB and rejects
USB disks, the live medium, read-only devices, zram, and device-mapper devices.
It creates a 1 GiB EFI partition labelled `NIXBOOT` and a Btrfs root labelled
`NIXROOT`. No network is needed for the install. The installed closure is the
`remembrance` profile, and the first boot is that host with the password set
during the install.

Existing NixOS hosts use the same label contract. Before switching an existing
host, relabel its root and ESP once:

```bash
sudo btrfs filesystem label / NIXROOT
boot_dev=$(findmnt -no SOURCE /boot)
sudo umount /boot
sudo fatlabel "$boot_dev" NIXBOOT
sudo mount /boot
sudo nixos-rebuild switch --flake .#remembrance
```

The first switch keeps the old generation; a label typo fails at the next boot
rather than changing the running system.

## Documentation

- [docs/architecture/dendritic.md](docs/architecture/dendritic.md): entity and aspect composition.
- [docs/architecture/distro.md](docs/architecture/distro.md): the distro flake, real profile, and storage contract.
- [docs/architecture/inputs.md](docs/architecture/inputs.md): the flake inputs and the removed ones.
- [docs/service-notes/distro-iso.md](docs/service-notes/distro-iso.md): build, test, and write the live ISO.
- [docs/service-notes/rootless-containers.md](docs/service-notes/rootless-containers.md): the container policy.
- [docs/service-notes/hydra-launcher.md](docs/service-notes/hydra-launcher.md): host-native Hydra and the universal trainer.
- [docs/service-notes/gaming-stability.md](docs/service-notes/gaming-stability.md): graphics, recovery, snapshots, and trainers.
- [docs/service-notes/zix.md](docs/service-notes/zix.md) and [tools/zix/README.md](tools/zix/README.md): the developer tool, pins, sandboxes, VMs.
- [secrets/README.md](secrets/README.md): the sops store and its recipients.

## Checks

```bash
nix flake check --all-systems --no-build
cd distro && nix flake check
```

`zix check` runs the fleet's quick suite. The installer disk test lives with the
distro: `cd distro && nix build .#checks.x86_64-linux.installer-disk-vm`.
