# PROJECT KNOWLEDGE BASE

**Updated:** 2026-11-07
**Branch:** main

## OVERVIEW

Personal Nix flake: two NixOS workstations, one Apple silicon macOS host, one
standalone Linux Home Manager host, and a separate distro flake for the personal
live/install medium. Den owns the entity and aspect tree; flake-parts owns the
fleet outputs.

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
│   │                    # storage-labels.nix x86-hardware.nix
│   │                    # mei.nix niri.nix noctalia.nix sops.nix ...
│   ├── flake/           # flake-parts outputs per system
│   ├── nixos/           # NixOS + HM payload owned by aspects
│   ├── shared/          # cross-platform HM payload for the mei user
│   ├── linux/           # Linux HM payload shared by NixOS and standalone-linux
│   ├── darwin/          # nix-darwin modules
│   └── standalone-linux/# standalone HM home and system-manager layer
├── distro/              # SEPARATE flake: ISO, installer, live/installed modules
│   ├── flake.nix
│   ├── modules/         # identity, base, live, installed, iso, installer
│   ├── pkgs/            # installer and Zenity GUI wrappers
│   ├── scripts/         # install.py, install-gui.sh
│   └── tests/           # config-eval, installer-disk-vm
├── apps/<system>/       # committed build/switch/clean scripts
├── tests/               # architecture, boundaries, config-eval, script args
├── pkgs/                # repo-local derivations (helium, omniwm, ...)
├── lib/                 # keys, caches, nixpkgs policy, helpers
├── tools/zix/           # zix: standalone CLI (own flake)
├── zix.json             # zix manifest
├── zix/managed/         # zix-generated package set and pins
├── secrets/             # sops/age stores
└── docs/                # architecture, service notes, dated audits
```

## HOSTS

- `remembrance`, `antagony`: NixOS x86_64 workstations.
- `entropy`: nix-darwin aarch64-darwin.
- `massive`: standalone Home Manager plus `systemConfigs.massive`.
- The distro flake owns `live` and `installed`; they are not main-flake hosts.

Identity lives in `modules/aspects/inventory.nix` under
`users.mei.identity`. Host aspects read `host.users.mei.identity` and
`host.hostName`. The standalone home also carries `identity` for
`system-manager`. There is no `machine`, `boot`, `storage`, capability, or
profile record.

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add or change a host | `modules/aspects/inventory.nix`, `modules/aspects/<host>.nix` | identity only in the entity |
| Add a capability | `modules/aspects/<kebab-name>.nix` | select it from a role/platform |
| Change the personal chain | `modules/aspects/{linux,darwin,workstation-*}.nix` | inward-only |
| Change the distro | `distro/` | separate flake; extends `remembrance` |
| Change the standalone system layer | `modules/standalone-linux/system.nix` | system-manager owns `/etc`, units, users, wrappers |
| Add a CachyOS package or change fish removal | `modules/standalone-linux/cachyos.nix` | pacman bootstrap unit |
| Change the SDDM theme | `modules/standalone-linux/cachyos.nix`, `pkgs/thyx.nix` | pinned v1.1.0; Blush preset |
| Configure OpenRGB | `modules/standalone-linux/openrgb.nix` | generated udev rules and `i2c-dev` |
| Change Hydra game launching | `pkgs/hydralauncher.nix`, `pkgs/hydralauncher-fhs.nix` | host-native; FHS fallback |
| Change game trainer launching | `pkgs/game-trainer.nix`, `pkgs/game-trainer.sh` | prefix detection, config, CE auto-attach |
| Change Cheat Engine | `pkgs/cheat-engine.nix` | pinned Linux build |
| Change the gaming health check | `pkgs/gaming-health.nix` | host Vulkan report |
| Change session recovery | `modules/standalone-linux/cachyos.nix`, `system.nix` | autologin, coredump, journal |
| Change the Nix update guard | `tools/gaming-update` | builds in a temporary copy |
| Change storage labels | `modules/nixos/storage-labels.nix` | `NIXBOOT`, `NIXROOT`; `my.storage.labels.enable` |
| Change the installer | `distro/scripts/install.py` + `distro/pkgs/distro-installer.nix` | `--test` covers disk logic |
| Change the graphical installer | `distro/scripts/install-gui.sh` + `distro/pkgs/distro-installer-gui.nix` | Zenity wrapper over the console installer |
| Add or pin a package | `zix add ...` | `tools/zix/README.md` |
| Change zix | `zix.json` | targets, tools, switches, checks |
| Change agent rules | `agent-settings.nix`, `agents/excalidraw.nix` | render with `nix build .#agent-settings` |
| Allow unfree | `lib/nixpkgs.nix` | name-only list |
| Change the fleet key | `lib/keys.nix` | one public key |
| Change binary caches | `lib/nix-caches.nix` | one list for all hosts |
| Build the ISO | `nix build ./distro#iso.live` | x86_64-linux only |
| Run checks | `tests/`, `distro/tests/` | see COMMANDS |

## CONVENTIONS

- One acyclic chain: `shared-policy -> {linux,darwin}-platform -> role ->
  hardware -> host`. The distro is not a second chain; it extends a real host.
- Behavior lives in an aspect; the inventory holds identity only.
- Agent rules live in `agent-settings.nix`; read it before editing code, prose,
  or a commit message. The `agent-settings` package and check import it, so a
  broken edit fails evaluation.
- Aspect files are flat and named `<kebab-name>.nix`.
- `distro/modules/*` are raw NixOS modules consumed by the distro flake. They do
  not take the Den `host` argument.
- Storage is a label contract. Never add a disk ID, UUID, `diskById`, disko
  device, or per-host storage branch.
- `zix` owns package-list edits. Entries live between `# BEGIN zix` / `# END
  zix` or in `zix/managed/`; the manifest is canonical. zix is a developer tool,
  not a host package.
- One ISO only: `distro/flake.nix`. The installer copies the prebuilt
  `nixosConfigurations.installed` closure, which is the real workstation profile.
- Nushell is the login shell; Bash is the only fallback. Do not add fish or zsh
  to `environment.shells`, and keep `/etc/shells` in step with the Nushell
  profile path on the standalone host.
- system-manager owns the standalone host's `/etc` files, systemd units, login
  account, wrappers, and pacman package bootstrap. Home Manager does not reach
  those.
- `secrets/*` is ignored except the tracked files. Do not commit private keys.
- Prefer one source for the key, cache list, user identity, unfree policy, and
  storage labels.

## ANTI-PATTERNS

- No machine authority, intake JSON, hardware enrollment, `host.machine`,
  `machineAuthority`, or per-host `boot`/`storage`/`capabilities` records.
- No disk IDs or `/dev/disk/by-id` in modules. The installer selects the disk.
- No `specialArgs` / `extraSpecialArgs` in `flake.nix`, `modules/flake`, or
  `modules/aspects`.
- No `nixosSystem` / `darwinSystem` / `homeManagerConfiguration` in `flake.nix`.
  Den creates the fleet configurations; the distro flake extends one of them.
- No sub-classification folders under `modules/aspects/`.
- No second Niri session authority: Noctalia owns bar, notifications, lock, and
  wallpaper. No polybar, dunst, rofi, waybar, mako, picom, bspwm, sxhkd, swaybg,
  awww/swww, i3lock, or betterlockscreen.
- No `live`/`installed` entities, ISO wiring, or distro modules in the main
  flake.
- No handwritten `zix/managed/*` or generated marker blocks.
- No kernel or filesystem command in the installer that skips the UEFI/live
  medium/size checks.

## COMMANDS

```bash
nix run .#build                # build the current host
nix run .#build-switch         # build and activate the current host
nix run .#home-switch          # standalone Home Manager switch
nix run .#update               # flake inputs + source pins
nix run .#clean                # delete generations older than 7 days
nix run .#zix -- --help        # developer tool
nix build .#agent-settings     # render the merged agent rules
nix build ./distro#iso.live    # live ISO
cd distro && nix build .#checks.x86_64-linux.installer-disk-vm
zix doctor

# checks
nix flake check --all-systems --no-build
cd distro && nix flake check
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-apps.sh
bash tests/dendritic-shells.sh
bash tests/script-args.sh
bash tests/prose.sh
nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'
```

## NOTES

- The main flake builds `x86_64-linux` and `aarch64-darwin`. The distro flake
  builds only `x86_64-linux`.
- `nix flake check` runs the fleet checks. The distro has its own check and VM
  test.
- The live ISO's installer needs UEFI, at least 16 GiB, and a non-live disk.
- LUKS, Secure Boot, persistence/vaults, public-release hardening, and the
  MeccanicOS command-bar/AI/fleet features are deferred.
- The distro pins the same nixpkgs revision as the fleet and follows it through
  the `nixos-config` input; keep the two pins in step when updating.
