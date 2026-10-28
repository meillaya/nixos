# PROJECT KNOWLEDGE BASE

**Updated:** 2026-10-28
**Branch:** main

## OVERVIEW

Personal Nix flake: two NixOS workstations, one Apple silicon macOS host, one
standalone Linux Home Manager host, and a personal live/install distro. Den owns
the entity and aspect tree; flake-parts owns the outputs.

There is no machine authority. Host identity is plain Den user data. Installed
NixOS systems use a fixed filesystem-label contract, so the installer accepts
any whole disk.

## STRUCTURE

```
nixos/
├── flake.nix            # inputs only + one mkFlake call; import-tree ./modules
├── modules/
│   ├── aspects/         # FLAT: hosts, roles, platforms, feature aspects
│   │                    # inventory.nix schema.nix nixpkgs.nix
│   │                    # <host>.nix workstation-*.nix linux.nix darwin.nix
│   │                    # storage-labels.nix x86-hardware.nix distro-*.nix
│   │                    # mei.nix niri.nix noctalia.nix sops.nix ...
│   ├── flake/           # flake-parts outputs per system
│   ├── distro/          # live/installed profile, ISO, and installer modules
│   ├── nixos/           # NixOS + HM payload owned by aspects
│   ├── shared/          # cross-platform HM payload for the mei user
│   ├── linux/           # Linux HM payload shared by NixOS and standalone-linux
│   ├── darwin/          # nix-darwin modules
│   └── standalone-linux/# standalone HM home and system-manager layer
├── apps/<system>/       # committed build/switch/clean scripts
├── tests/               # architecture, boundaries, config-eval, policy, distro
├── bin/                 # operator entry points (cachix setup)
├── scripts/distro/      # the live ISO installer driver
├── scripts/check-unfree-pins.py
├── pkgs/                # repo-local derivations (helmet, omniwm, installer)
├── tools/zix/           # zix: standalone CLI (own flake)
├── zix.json             # zix manifest
├── zix/managed/         # zix-generated package set and pins
├── config/              # package exceptions only
├── secrets/             # sops/age stores
└── docs/                # architecture, service notes, dated audits
```

## HOSTS

- `remembrance`, `antagony`: NixOS x86_64 workstations.
- `entropy`: nix-darwin aarch64-darwin.
- `massive`: standalone Home Manager plus `systemConfigs.massive`.
- `live`: the ISO's live session.
- `installed`: the prebuilt system copied to the target disk.

Identity lives in `modules/aspects/inventory.nix` under
`users.mei.identity`. Host aspects read `host.users.mei.identity` and
`host.hostName`. There is no `machine`, `boot`, `storage`, capability, or
profile record.

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add or change a host | `modules/aspects/inventory.nix`, `modules/aspects/<host>.nix` | identity only in the entity |
| Add a capability | `modules/aspects/<kebab-name>.nix` | select it from a role/platform |
| Change the personal chain | `modules/aspects/{linux,darwin,workstation-*}.nix` | inward-only |
| Change the distro | `modules/distro/` | live/installed/ISO/installer |
| Change storage labels | `modules/nixos/storage-labels.nix` | `NIXBOOT`, `NIXROOT`, Btrfs subvolumes |
| Change the installer | `scripts/distro/install.py` + `pkgs/distro-installer.nix` | `--test` covers disk logic |
| Add or pin a package | `zix add ...` | `tools/zix/README.md` |
| Change zix | `zix.json` | targets, tools, switches, checks |
| Allow unfree | `config/package-exceptions.json` | 90-day entry |
| Build the ISO | `nix build .#iso.live` | x86_64-linux only |
| Run checks | `tests/` | see COMMANDS |

## CONVENTIONS

- One acyclic chain: `shared-policy -> {linux,darwin}-platform -> role ->
  hardware -> host`. The distro chain is `shared-policy -> distro-platform ->
  distro-role -> live|installed`.
- Behavior lives in an aspect; the inventory holds identity only.
- Aspect files are flat and named `<kebab-name>.nix`.
- `modules/distro/*` are raw NixOS modules imported by the host aspects or the
  ISO extension. They do not take the Den `host` argument.
- Storage is a label contract. Never add a disk ID, UUID, `diskById`, disko
  device, or per-host storage branch.
- `zix` owns package-list edits. Entries live between `# BEGIN zix` / `# END
  zix` or in `zix/managed/`; the manifest is canonical.
- One ISO only: `flake.iso.live`. The installer copies the prebuilt
  `nixosConfigurations.installed` closure.
- `secrets/*` is ignored except the tracked files. Do not commit private keys.

## ANTI-PATTERNS

- No machine authority, intake JSON, hardware enrollment, `host.machine`,
  `machineAuthority`, or per-host `boot`/`storage`/`capabilities` records.
- No disk IDs or `/dev/disk/by-id` in modules. The installer selects the disk.
- No `specialArgs` / `extraSpecialArgs` in `flake.nix`, `modules/flake`, or
  `modules/aspects`.
- No `nixosSystem` / `darwinSystem` / `homeManagerConfiguration` in `flake.nix`.
  Den creates configurations.
- No sub-classification folders under `modules/aspects/`.
- No second Niri session authority: Noctalia owns bar, notifications, lock, and
  wallpaper. No polybar, dunst, rofi, waybar, mako, picom, bspwm, sxhkd, swaybg,
  awww/swww, i3lock, or betterlockscreen.
- No handwritten `zix/managed/*` or generated marker blocks.
- No kernel or filesystem command in the installer that skips the UEFI/live
  medium/size checks.

## COMMANDS

```bash
nix run .#build                # build the toplevel
nix run .#build-switch         # build and activate
nix run .#home-switch          # standalone Home Manager switch
nix run .#update               # flake inputs + pins
nix run .#clean                # delete generations older than 7 days
nix build .#iso.live           # live ISO
nix build .#checks.x86_64-linux.installer-disk-vm
zix doctor
zix --help

# checks
nix flake check --all-systems --no-build
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-apps.sh
bash tests/dendritic-shells.sh
bash tests/package-policy.sh
bash tests/prose.sh
nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'
```

## NOTES

- The flake builds `x86_64-linux` and `aarch64-darwin`. The ISO and installer
  test exist only for `x86_64-linux`.
- `nix flake check` also runs the `.sh` checks and package policy as
  `perSystem` derivations.
- The live ISO's installer needs UEFI, at least 16 GiB, and a non-live disk.
- LUKS, Secure Boot, persistence/vaults, public-release hardening, and the
  MeccanicOS command-bar/AI/fleet features are deferred.
- `config/package-exceptions.json` is version-exact; nixpkgs drift fails the
  first output that includes the package.
- Unfree pins are checked with `scripts/check-unfree-pins.py`.
