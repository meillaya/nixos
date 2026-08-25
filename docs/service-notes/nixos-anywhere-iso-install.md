# NixOS install via the per-host installer ISO (no-kexec)

Installation is ISO-first. You build a per-host installer ISO from the
flake, boot it on the target machine, and then run `nixos-anywhere` to
install the flake over the network. Because the target is already
running the NixOS installer, `nixos-anywhere` skips `kexec` entirely.

## Build the per-host ISO

```bash
nix build .#iso.<host>
```

`.#iso.<host>` is shorthand for
`.#nixosConfigurations.<host>.config.system.build.isoImage`. The flake
exposes exactly one ISO variant (installer) per NixOS host:

- `.#iso.remembrance`
- `.#iso.antagony`

The ISO builder lives in `modules/flake/iso-images.nix`. The hosts
disable the initrd while their boot state is `"disabled"` (pending
enrollment), so the ISO variant re-enables it (`boot.initrd.enable =
lib.mkForce true`) to keep the installer bootable.

## Boot the ISO on the target

Boot the ISO on the target machine. A Proxmox VM works well:

- Firmware: **OVMF (UEFI)** — the enrolled boot policy is
  `boot.state = "uefi"` with `secureBoot = false` and
  `configurationLimit = 10`.
- RAM: **at least 4 GB** — the installer runs entirely in RAM, and
  `nixos-anywhere` will not `kexec` into a separate image, so the
  installer's own memory footprint is the only constraint.
- Disk: attach the target disk as a whole device (never a partition).
  The enrolled storage profile binds a `/dev/disk/by-id` basename, not a
  kernel-assigned path.

## Why kexec is skipped

The built ISO sets `VARIANT_ID=installer` in `/etc/os-release` (NixOS
23.05+). When `nixos-anywhere` connects to the target, it checks
`/etc/os-release` for that identifier. If the installer is detected, it
does **not** `kexec` into its own image — it installs directly from the
already-booted installer environment. This is what makes the flow work
on targets with limited RAM or no `kexec` support.

## Run the install

From the operator side, with the target booted into the ISO and
reachable on the network:

```bash
nix run github:nix-community/nixos-anywhere -- --flake '.#<host>' --target-host root@<ip>
```

For example:

```bash
nix run github:nix-community/nixos-anywhere -- --flake '.#antagony' --target-host root@192.168.1.50
```

`nixos-anywhere` auto-detects the installer (via `VARIANT_ID=installer`)
and skips kexec. It partitions the disk with the enrolled Disko layout
(`modules/nixos/disk-config.nix`), writes the flake, and activates the
system.

## The four-enrollment gate

The trust boundary for any physical install is the reviewed machine
record in `modules/entities/_machine-authority/model.nix`. A host is
installable only when all four enrollments are set:

| Field | Enrolled value |
| --- | --- |
| `boot.state` | `uefi` |
| `storage.profile` | `single-gpt-btrfs` |
| `publicTrust.state` | `enrolled` |
| `secretTrust.state` | `enrolled` |

Until a reviewed enrollment binds all exact host + device facts, the
repo refuses physical installs. The enrollment writer is the KEPT
hardware-intake validator:

```bash
bin/nix-config-hardware-intake create <base.json> <candidate.json> <reviewer> <appliedAt>
bin/nix-config-hardware-intake validate <base.json> <intake.json>
```

`create` builds a canonical, reviewed RFC-6902 intake document from the
current (disabled) machine record and the enrolled candidate; `validate`
applies it and re-validates the resulting declaration against the same
contracts (`scripts/hardware/contracts.py`) that gate the install. The
operator reviews the diff and commits the machine record to `model.nix`
manually.

## Day 2: deploy-rs

After the first install, day-2 updates go through deploy-rs, wired in
`flake.nix` as `deploy.nodes.remembrance`, `deploy.nodes.antagony`,
`deploy.nodes.entropy`, and `deploy.nodes.massive` (home-only profile).
See the deploy-rs wiring for the activation commands.

## References

- <https://nix-community.github.io/nixos-anywhere/quickstart.html>
- <https://nix-community.github.io/nixos-anywhere/howtos/no-os.html>
- <https://github.com/nix-community/disko/blob/master/docs/disko-install.md>
- <https://nixos.org/manual/nixos/stable/>