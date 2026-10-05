# NixOS install via the per-host installer ISO (no-kexec)

Installation is ISO-first: you build a per-host installer ISO from the flake,
boot it on the target machine, and install the flake from there. Two entry
points drive it:

- **On the target, one command** — `nix run github:meillaya/nixos#install`
  probes the machine's hardware, writes the reviewed enrollment, and installs.
  No second machine, no manual SSH setup.
- **From an operator machine over SSH** — `bin/host-install.sh --target-host <ip> --yes`,
  or the manual `nixos-anywhere` invocation below.

Both drive the same reviewed enrollment pipeline, and because the target is
already running the NixOS installer, `nixos-anywhere` skips `kexec` entirely.

## Build the per-host ISO

```bash
nix build .#iso.<host>        # .#iso.remembrance / .#iso.antagony
ls result/iso/                # -> nixos-<label>-x86_64-linux.iso
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

`.#iso.<host>` is shorthand for
`.#nixosConfigurations.<host>.config.system.build.images.iso`. The flake
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
on targets with limited RAM or no `kexec` support, and what makes the
one-command self-install work at all: there the orchestrator runs on the
same machine it installs, so a `kexec` would kill its own process.
`modules/flake/iso-images.nix` sets the marker explicitly; the upstream
installer images (see below) set it themselves.

## Run the install

### One command on the target

Boot the ISO, get the network up (`nmtui` for Wi-Fi), then:

```bash
sudo nix run --extra-experimental-features 'nix-command flakes' \
  github:meillaya/nixos#install -- --yes
```

The app detects the machine (a ThinkPad P52 maps to `antagony`; otherwise
pass `--host <name>`), probes the real hardware through the same intake
pipeline the ISO's `hardware-enroll` oneshot uses, commits the enrollment
into a work tree (`/root/nixos-install`), folds the fresh host key into
`secrets/remembrance-keys.yaml` when the operator secrets are present,
and then runs the `nh os build` gate plus `nixos-anywhere` against
`root@127.0.0.1`.

```bash
sudo nix run .#install --                 # probe + enroll, print the summary
sudo nix run .#install -- --yes           # build gate + install + reboot
sudo nix run .#install -- --dry-run       # print the plan, execute nothing
mount /dev/sdX1 /mnt/usb                  # a stick that survives the reboot
sudo nix run .#install -- --skip-fold --save /mnt/usb/enroll --yes
```

Without `--yes` the run stops after the enrollment checkpoint. `--skip-fold`
keeps the host key local and requires `--save DIR` on persistent storage (the
ISO environment is RAM); the enrollment commit inside the work tree is also
lost on reboot, so copy it out with `--save` and commit it to the repo
afterwards. The install stage itself refuses to run unless `/` is a live
tmpfs/overlay root, and re-checks `--yes` inside `bin/host-install.sh`.

### Manual operator-side install

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
system. `bin/host-install.sh` wraps exactly this command with the
enroll → fold → gate → install → verify stages.

## Using the official NixOS minimal ISO

The upstream minimal installer (`nixos-minimal-*.iso` from nixos.org) also
works for the one-command app path: it runs sshd with `PermitRootLogin = "yes"`,
has a tmpfs root, sets `VARIANT_ID=installer` itself, brings NetworkManager,
and carries Nix with a nixpkgs copy. Differences to keep in mind:

- Keep `--extra-experimental-features 'nix-command flakes'` — flakes are not
  enabled on it by default.
- It has no `hardware-enroll` oneshot and no baked-in base declaration, so
  only the flake app works; `bin/host-install.sh` needs the per-host ISO.
- It carries none of the repo's keys; the app installs its own root key for
  the self-SSH phase, so that is fine.
- The live environment is RAM-backed: the app's tool closure (including `nh`,
  which the pinned input builds from source) plus the system closure are
  fetched/built into it. A few GB of free RAM are enough.
- Same secret caveat as the flake ISO: without `secrets/remembrance-keys.yaml`
  and the age identity, use `--skip-fold --save <persistent-dir>`.

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
repo refuses physical installs. The enrollment writers are the intake
pipeline (the ISO's `hardware-enroll` oneshot or the `install` app) and the
KEPT hardware-intake validator:

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

A host that has not been enrolled yet is handled the same way at install
time: the one-command app probes the machine, generates the trust fixture
from the fleet record (`scripts/hardware/gen_trust.py` falls back to the
fleet's operator facts until the host has its own record), and writes
`config/hosts/intake/<host>.json` into its work tree. `model.nix` loads
that file as soon as it exists — for `antagony` the inline pending record
is only the build-time base before the first enrollment.

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