# The dendritic graph

The repository is one Den tree. Entity declarations live in
`modules/aspects/inventory.nix`; behavior lives in aspects next to it. There are
no sub-classification folders: `ls modules/aspects/` is the table of contents.

## Entities

`inventory.nix` declares hosts and standalone homes with identity data only:

```nix
den.hosts.x86_64-linux.remembrance.users.mei.identity = {
  name = "mei";
  home = "/home/mei";
  uid = 1000;
  gid = 100;
};
```

Den defaults `host.hostName` to the entity name and `host.system` to the
inventory key. Aspects read `host.hostName` and
`host.users.mei.identity`; there is no `host.machine` record and no flake-level
machine authority.

The personal hosts are `remembrance` and `antagony` (NixOS), `entropy`
(nix-darwin), and `massive` (standalone Home Manager plus system-manager). The
distro adds `live` and `installed`.

`modules/aspects/schema.nix` extends Den with the user `identity` type, the
three class payload options, and `homeDirectory` for standalone homes.

## Composition

Composition is inward-only:

```text
named host -> role -> platform -> feature aspects
```

- `workstation-role-linux` = `linux-platform` + Niri + Noctalia + Home Manager.
- `linux-platform` = shared nixpkgs policy, the personal NixOS base, rootless
  containers, sops, desktop media, preservation, stylix, nix-direnv, and generic
  x86 hardware.
- `workstation-role-darwin` = the Darwin platform plus the dock module.
- `distro-role` = `distro-platform` + Niri + Noctalia + Home Manager.
- `distro-platform` = shared nixpkgs policy, the NixOS base, rootless
  containers, desktop media, stylix, nix-direnv, and generic x86 hardware.

A host aspect may include a raw module with `nixos.imports` or `darwin.imports`
when the module is not itself an aspect. Personal hosts and `installed` include
`storage-labels`; `live` does not, because the ISO owns its media.

## Host and distro data

`modules/nixos/system.nix` is the shared NixOS base. It reads
`host.users.mei.identity` for the account, home, and SSH key paths. Personal
services that should not start on a fresh distro (tailscale, syncthing, the
personal SSH trust anchor) are switched off by `modules/distro/base.nix` with
`lib.mkForce`.

`modules/distro/` owns the distro:

- `identity.nix`: name, id, hostname, live user, and storage labels.
- `base.nix`: shared live/installed overrides.
- `live.nix`: auto-login, passwordless sudo, and a temporary root for the
  normal `nixosConfigurations.live` build.
- `installed.nix`: fixed hostname and SSH without trusted keys.
- `iso.nix`: ISO media plumbing.
- `installer.nix`: the offline installer package and its options.

## Storage

Every installed NixOS system reads the same labels:

| Label | Filesystem | Mount |
| --- | --- | --- |
| `NIXBOOT` | FAT32 | `/boot` |
| `NIXROOT` | Btrfs, `@root` | `/` |
| `NIXROOT` | Btrfs, `@home` | `/home` |
| `NIXROOT` | Btrfs, `@nix` | `/nix` |
| `NIXROOT` | Btrfs, `@log` | `/var/log` |

`modules/nixos/storage-labels.nix` owns the mounts. The installer creates the
labels on the selected disk. No aspect references a disk ID or a UUID.

## Flake outputs

- `nixosConfigurations.{remembrance,antagony,live,installed}`
- `darwinConfigurations.entropy`
- `homeConfigurations.massive`
- `systemConfigs.massive`
- `iso.live` and `isoConfig.live`
- `deploy.nodes` for the four personal hosts

`flake.nix` holds inputs and one `mkFlake` call. Den creates the
configurations; `modules/flake/` creates the per-system outputs.

## Tests

`tests/dendritic-architecture.sh` pins the flat tree, the entity shape, and the
absence of machine authority. `tests/dendritic-boundaries.sh` pins the
identity sources and the retired desktop stack. `dendritic-config-eval.nix`
evaluates the real hosts plus the live and installed profiles and the ISO
contract. `tests/installer-disk-vm.nix` exercises partitioning on a blank
virtual disk.
