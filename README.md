# nixos

One flake for four personal machines and a small personal NixOS live/install
distro. Den owns the host and user entities; flake-parts owns the outputs.

## Hosts

- `remembrance`, `antagony`: NixOS x86_64 workstations.
- `entropy`: nix-darwin on Apple silicon.
- `massive`: standalone Home Manager plus a system-manager layer on CachyOS.
- `live`, `installed`: the personal distro. `live` is the ISO session,
  `installed` is the prebuilt system the installer copies to a target disk.

Host identity lives in `modules/aspects/inventory.nix` as
`users.mei.identity`. There is no machine-authority record, intake document, or
per-host disk binding.

## Quickstart

```bash
nix run .#build                # build the toplevel, change nothing
nix run .#build-switch         # build and activate this host
nix run .#nh -- os dry-build   # print the activation diff
```

`nh` is the day-2 tool. `nix run .#update` refreshes the flake inputs and
`nix run .#clean` drops system generations older than seven days.

## Install the distro

Build the live ISO on an x86_64-linux machine, write it to a USB stick, boot
UEFI, and run the installer from the live session:

```bash
nix build .#iso.live
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
sudo nixos-install-tui
```

The installer accepts any whole disk of at least 16 GiB, creates a 1 GiB EFI
partition labelled `NIXBOOT` and a Btrfs root labelled `NIXROOT`, then copies
the prebuilt installed system from the ISO. No network is needed for the
install.

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
- [docs/architecture/distro.md](docs/architecture/distro.md): live ISO, installed system, and storage contract.
- [docs/architecture/inputs.md](docs/architecture/inputs.md): the extra flake inputs.
- [docs/service-notes/distro-iso.md](docs/service-notes/distro-iso.md): build, test, and write the live ISO.
- [docs/service-notes/rootless-containers.md](docs/service-notes/rootless-containers.md): the container policy.
- [docs/service-notes/zix.md](docs/service-notes/zix.md) and [tools/zix/README.md](tools/zix/README.md): packages, pins, sandboxes, VMs.
- [secrets/README.md](secrets/README.md): the sops store and its recipients.
- [agent-settings.nix](agent-settings.nix): the rules agents follow here.
- [agents/excalidraw.nix](agents/excalidraw.nix): the hand-drawn diagram rules imported by `agent-settings.nix`.

## Checks

```bash
nix flake check --all-systems --no-build
```

`zix check` runs the same suite. The installer disk test is
`nix build .#checks.x86_64-linux.installer-disk-vm`.
