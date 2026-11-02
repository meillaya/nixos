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
inventory key. Aspects read `host.hostName` and `host.users.mei.identity`; there
is no `host.machine` record and no flake-level machine authority.

The personal hosts are `remembrance` and `antagony` (NixOS), `entropy`
(nix-darwin), and `massive` (standalone Home Manager plus system-manager). The
distro is a separate flake under `distro/`; it is not an entity in this
inventory.

`modules/aspects/schema.nix` extends Den with the user `identity` type, the
three class payload options, and `homeDirectory` for standalone homes.

## Composition

Composition is inward-only:

```text
named host -> role -> platform -> feature aspects
```

- `workstation-role-linux` = `linux-platform` + Niri + Noctalia + Home Manager.
- `linux-platform` = shared nixpkgs policy, the personal NixOS base, rootless
  containers, sops, desktop media, and generic x86 hardware.
- `workstation-role-darwin` = the Darwin platform plus the dock module.
- `massive` = the user aspect plus the standalone rootless-container, Noctalia,
  and desktop-media aspects, with the system-manager layer in
  `modules/standalone-linux/`.

A host aspect may include a raw module with `nixos.imports` or `darwin.imports`
when the module is not itself an aspect. Personal hosts include
`storage-labels`; the standalone home and Darwin host do not.

## Host data

`modules/nixos/system.nix` is the shared NixOS base. It reads
`host.users.mei.identity` for the account, home, group, and SSH key paths.
`modules/nixos/storage-labels.nix` owns the label contract and exposes
`my.storage.labels.enable`, so a profile without an installed disk can opt out
without forcing the mount set away.

`modules/shared/home-manager.nix` is the cross-platform Home Manager payload.
Nushell and Bash are the only configured shells; Nushell is the login shell.

## The distro boundary

`distro/` is its own flake. It consumes this flake as a path input and extends
`nixosConfigurations.remembrance` with:

- `distro/modules/base.nix`: the live/installed overrides.
- `distro/modules/live.nix`: auto-login, passwordless sudo, and the ISO root.
- `distro/modules/installed.nix`: a fixed hostname and SSH without trusted keys.
- `distro/modules/iso.nix`: ISO media plumbing.
- `distro/modules/installer.nix`: the offline installer package and its options.
- `distro/modules/identity.nix`: name, id, hostname, live user, and labels.

The installed closure is the real workstation profile, not a second
`distro-role`. The distro pins the same nixpkgs revision as the fleet and
follows it through `nixos-config`.

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
labels on the selected disk. No aspect references a disk ID or a UUID. The live
profile sets `my.storage.labels.enable = false` because its root is the ISO
medium.

## Flake outputs

- `nixosConfigurations.{remembrance,antagony}`
- `darwinConfigurations.entropy`
- `homeConfigurations.massive`
- `systemConfigs.massive`
- `checks`, `apps`, `packages`, `devShells`

`flake.nix` holds inputs and one `mkFlake` call. Den creates the
configurations; `modules/flake/` creates the per-system outputs. The distro
flake owns `nixosConfigurations.{live,installed}`, `iso.live`, and
`isoConfig.live`.

## Tests

`tests/dendritic-architecture.sh` pins the flat tree, the entity shape, the
absence of machine authority, and the distro boundary. `tests/dendritic-
boundaries.sh` pins the identity sources and the retired desktop stack.
`tests/dendritic-config-eval.nix` evaluates the personal hosts and the package
policy. The distro's own `tests/config-eval.nix` evaluates the live, installed,
and ISO contracts; `distro/tests/installer-disk-vm.nix` exercises partitioning
on a blank virtual disk.
