# The nixos fleet manual

This repository configures four personal machines and a separate live/install
medium from one Nix flake. Den owns the host and user entities and composes
aspects into classes. flake-parts owns the per-system outputs. The distro is its
own flake under `distro/`.

The design rule that everything else follows: hosts and users carry identity
data, aspects own behavior, and the flake exposes outputs. There is no machine
record, no per-host storage binding, and no second source for a key, a cache, or
a package pin.

## Hosts

| Host | System | Role | Applies with |
| --- | --- | --- | --- |
| `remembrance` | NixOS `x86_64-linux` | `workstation-role-linux` | `nix run .#build-switch` |
| `antagony` | NixOS `x86_64-linux` | `workstation-role-linux` | `nix run .#build-switch` |
| `entropy` | nix-darwin `aarch64-darwin` | `workstation-role-darwin` | `nix run .#build-switch` |
| `massive` | CachyOS `x86_64-linux` | standalone Home Manager plus `systemConfigs.massive` | `nix run .#home-switch` |

The users on the NixOS hosts share one account identity. The standalone host has
its own primary group, so its identity carries `gid = 1000` instead of the shared
`gid = 100`. Every host name comes from Den, which defaults `host.hostName` to
the entity name.

## Composition

The entity registry lives in `modules/aspects/inventory.nix` and holds only
identity data:

```nix
den.hosts.x86_64-linux = {
  remembrance.users.mei.identity = linuxIdentity;
  antagony.users.mei.identity = linuxIdentity;
};
den.hosts.aarch64-darwin.entropy.users.mei.identity = darwinIdentity;
den.homes.x86_64-linux.massive = {
  userName = "mei";
  homeDirectory = "/home/mei";
  identity = massiveIdentity;
};
```

`modules/aspects/schema.nix` adds the user `identity` option, the `nixos`,
`darwin`, and `homeManager` class payload options, and the standalone home's
`homeDirectory` option. A standalone home also receives its package set from the
shared nixpkgs policy, so overlays and pins apply there too.

Composition runs inward only:

```text
named host -> role -> platform -> feature aspects
```

The Linux side:

```nix
den.aspects.workstation-role-linux.includes = [
  den.aspects.linux-platform
  den.aspects.niri
  den.aspects.noctalia
  den.aspects.luciole
  den.aspects.linux-desktop
];

den.aspects.linux-platform.includes = [
  den.aspects.shared-policy
  den.aspects.nixos-base
  den.aspects.rootless-containers
  den.aspects.sops
  den.aspects.desktop-media
  den.aspects.x86-hardware
];
```

The macOS side is the same shape:

```nix
den.aspects.workstation-role-darwin.includes = [
  den.aspects.darwin-platform
  den.aspects.darwin-dock
];
```

An aspect can carry a payload per class, and can include other aspects. A raw
module goes in `imports` when no aspect owns it:

```nix
den.aspects.noctalia = {
  nixos = {
    imports = [ inputs.noctalia.nixosModules.default ];
    programs.noctalia.enable = true;
  };
  homeManager = {
    imports = [ inputs.noctalia.homeModules.default ];
    programs.noctalia.enable = true;
  };
};
```

### How Home Manager content reaches a machine

The two kinds of machine deliver Home Manager content differently, and new
aspects have to fit the one they target.

- On NixOS hosts, Home Manager is a user service under the host. Host aspects
  hand modules to their users with `provides.to-users.homeManager`. The
  `linux-desktop` aspect provides `modules/nixos/home-manager.nix` this way, and
  `nix-plist-manager` and `darwin-home` do the same on Darwin. A plain
  `homeManager` payload on a role aspect reaches the standalone home, not the
  NixOS users.
- On the standalone host, `den.homes` evaluates the `massive` aspect directly.
  Its `homeManager` payload imports `modules/standalone-linux/home-manager.nix`
  with the home identity.

The `luciole` aspect shows both routes for one feature:

```nix
{ inputs, ... }:
let
  module = {
    imports = [ inputs.luciole.homeModules.default ];
    programs.luciole.enable = true;
  };
in
{
  den.aspects.luciole = {
    # NixOS workstations consume this through their users.
    provides.to-users.homeManager = module;
    # The standalone home consumes this directly.
    homeManager = module;
  };
}
```

### Add a host

1. Add the identity to `modules/aspects/inventory.nix` under `den.hosts` or
   `den.homes`.
2. Add `modules/aspects/<name>.nix` selecting the role and, for a NixOS or
   Darwin machine, the hardware facts.
3. Add `den.aspects.storage-labels` when the host installs to a disk.
4. Add the exact name to the expected sets in
   `tests/dendritic-config-eval.nix`.

### Add a feature

1. Add one flat `modules/aspects/<kebab-name>.nix`.
2. Put the implementation in the matching payload directory:
   `modules/nixos`, `modules/darwin`, `modules/linux`, `modules/shared`, or
   `modules/standalone-linux`.
3. Select it from a platform or role aggregator, not from a host directly.

A capability used by one host can stay inline in that host's aspect.

## Repository layout

```text
flake.nix              inputs and one mkFlake call
agent-settings.nix     agent rules, rendered by `nix build .#agent-settings`
agents/                the hand-drawn figure rules
modules/
  aspects/             the flat Den tree: hosts, roles, platforms, features
  flake/               flake-parts outputs: apps, checks, packages, systems
  nixos/               NixOS payload, including the NixOS Home Manager module
  linux/               Linux Home Manager payload shared by three hosts
  shared/              cross-platform Home Manager payload
  darwin/              nix-darwin payload and macOS Home Manager module
  standalone-linux/    Home Manager and system-manager layer for massive
distro/                separate flake: ISO, installer, live and installed profiles
apps/<system>/         committed build, build-switch, and clean scripts
lib/                   keys, caches, nixpkgs policy
pkgs/                  repo-local derivations
tests/, distro/tests/  evaluation and architecture checks
tools/zix/             the developer CLI, its own flake
docs/                  this manual and the logo
```

`flake.nix` holds no `nixosSystem`, `darwinSystem`, or
`homeManagerConfiguration` call. Den creates the configurations and
`modules/flake` creates the outputs.

## Shared policy

Three files provide the fleet-wide facts.

### `lib/nixpkgs.nix`

The nixpkgs policy has three jobs:

- It allows a short, name-only list of unfree packages: `android-studio`,
  `google-chrome`, `intellij-idea`, `obsidian`, `postman`, `pycharm`, `raycast`,
  `spotify`, `terraform`, `unrar`, and `vagrant`.
- It applies the overlays every host shares. `ghostty-bin` provides the signed
  macOS DMG because upstream's source package does not build there. The zix pin
  overlay applies `zix/managed/pins.json` through nixpkgs-multiverse.
  `rustSystemLibsOverlay` adds the system library inputs that the current
  nixpkgs cargo setup hook requires for `fnm`, `tectonic-unwrapped`, and `yaak`.
- It exposes `mkPkgs`, the single package-set constructor. NixOS, nix-darwin,
  the standalone home, and the flake apps all use it.

### `lib/nix-caches.nix`

One substituter list for every host: `noctalia.cachix.org`,
`nix-community.cachix.org`, and `cache.nixos.org`, with their public keys. The
NixOS hosts and the standalone system layer both read it.

### `lib/keys.nix`

One public key, the fleet GitHub key. The user and root authorize it on NixOS
and Darwin hosts. The distro profile empties both lists, so the live and
installed media trust no personal key until an operator adds one.

### Storage labels

Installed NixOS systems never name a disk. `modules/nixos/storage-labels.nix`
mounts a fixed label contract:

| Label | Filesystem | Mount |
| --- | --- | --- |
| `NIXBOOT` | FAT32 | `/boot` |
| `NIXROOT` | Btrfs `@root` | `/` |
| `NIXROOT` | Btrfs `@home` | `/home` |
| `NIXROOT` | Btrfs `@nix` | `/nix` |
| `NIXROOT` | Btrfs `@log` | `/var/log` |

The installer creates those labels on any eligible disk, so the same closure
boots from any of them. The live profile sets `my.storage.labels.enable = false`
because its root is the medium. No module carries a disk ID, UUID, or disko
device.

## NixOS workstations

`modules/nixos/system.nix` is the shared NixOS base. It reads the host and user
from the entity and owns:

- systemd-boot with a 42-generation limit, the latest kernel, and `zfs.forceImportRoot = false` because the fleet does not use ZFS;
- the Noctalia greeter through greetd, with `Niri` preselected and the greeter pointed at the session desktop files;
- OpenSSH with the fleet key for the user and root;
- Tailscale and Syncthing, with Syncthing limited to LAN discovery and configured under the user's home;
- WirePlumber, NetworkManager, power-profiles-daemon, UPower, libinput, gvfs, tumbler, Bluetooth, and processor microcode;
- the user's `i2c` and `video` groups, and a NOPASSWD rule for `reboot`;
- fonts, `gitFull`, and `stateVersion = "21.05"`. Leave the state version alone.

Home Manager content comes from `modules/nixos/home-manager.nix`, which imports
`modules/linux/home-manager.nix` and then adds the NixOS package list. The
`linux-desktop` aspect supplies it to every user of the host:

```nix
provides.to-users.homeManager = import ../nixos/home-manager.nix;
```

That module sets the username, home directory, package list, managed files,
GTK theme, udiskie, and gpg. `useGlobalPkgs` and `useUserPackages` are on, and
collisions are backed up with `backupFileExtension = "before-home-manager"`.

The user aspect (`modules/aspects/mei.nix`) carries the cross-platform Home
Manager payload and three activation scripts that run after `writeBoundary`:

- `installGithubSshKey` decrypts the escrowed GitHub key with sops and installs
  `~/.ssh/id_github` with mode 0600. It validates the key with `ssh-keygen`
  first, never overwrites an existing `id_ed25519`, and never fails a switch.
- `setupGitSigningKey` generates the per-machine signing key once and refreshes
  `~/.ssh/allowed_signers`.
- `fixSshConfigPermissions` runs after `linkGeneration` and replaces the
  Home Manager store link at `~/.ssh/config` with a user-owned 0600 copy.
  OpenSSH rejects the store link inside a user namespace with "Bad owner or
  permissions", which otherwise breaks `git push` from FHS wrappers and
  sandboxes. The Home Manager entry carries `force = true` so the next switch
  treats the copy as replaceable.

Nushell is the login shell and Bash is the only fallback. The Nushell PATH lists
the nix profiles plus `/run/wrappers/bin`, `/run/system-manager/sw/bin`, and
`/usr/bin`, so `sudo` and `run0` resolve even when a GUI launcher hands the shell
a reduced environment. `nix run .#build-switch` prepends the wrapper and system
directories as well, because nh calls `sudo` by name.

## The macOS host

`entropy` composes `darwin-platform` (`shared-policy`, `darwin-base`,
`nix-plist-manager`, `sops`, `darwin-home`) with `darwin-dock`.

- `modules/darwin/base.nix` sets the Nix settings (automatic store optimisation,
  free-space thresholds, the shared caches, weekly garbage collection), enables
  Remote Login for the fleet key, runs Tailscale as a LaunchDaemon, loads the
  package set at system level so nix-darwin copies app bundles into
  `/Applications/Nix Apps`, and runs OmniWM at login. The `nix-gc` launchd job
  also runs at load and logs to `/var/log/nix-gc.log`.
- `nix-plist-manager` is the only author of the macOS preference keys it
  manages. `modules/darwin/mac-settings-{system,user}.nix` hold those keys.
  `system.defaults` keeps the remaining settings.
- `modules/darwin/user-home.nix` is the Home Manager module, with a backup
  command that never clobbers an earlier backup.
- `modules/darwin/packages.nix` starts from the shared package list and adds the
  macOS-only apps, including the local `ghostty-bin` DMG, OmniWM, and the
  PyCharm override that drops the Cython debug hook.
- `nix run .#build-switch` runs `darwin-rebuild switch` through sudo.

There is no Homebrew in this configuration. Look packages up with `mcp-nixos` or
the unstable package index before adding them.

## massive, the standalone Linux host

`massive` runs CachyOS. Home Manager owns the user payload; system-manager owns
the system state that Home Manager cannot reach on a foreign distribution.
`massive` is the only host with a system layer outside NixOS.

### The system-manager layer

`systemConfigs.massive` is built from `modules/standalone-linux/system.nix`,
`cachyos.nix`, and `openrgb.nix`. It owns:

- the static hostname, applied to the file, the kernel, and systemd-hostnamed;
- `tailscaled` from nixpkgs, on the distribution's socket and state paths;
- `/run/opengl-driver`, a symlink to a `buildEnv` of Mesa, libglvnd, and the
  VA-API drivers;
- `/etc/nix/nix.custom.conf`, with `trusted-users = root @wheel` and the shared
  substituter list;
- the 970 EVO data disk at `/mnt/970`, with a oneshot that gives the desktop
  user ownership;
- the login account, its Nushell shell, and `/etc/shells`;
- the `unix_chkpwd` PAM helper wrapper;
- the CachyOS pacman bootcstrap and fish removal;
- the Thyx SDDM theme (the Blush preset) and its Qt6 packages;
- OpenRGB with generated udev rules and `i2c-dev`;
- a Steam PATH drop-in, the gaming autologin and journal settings, and the
  Gamescope HDR session.

Apply it from the repository root:

```bash
nix run github:numtide/system-manager -- switch --flake .#massive --sudo
```

The kernel, the bootloader, and pacman stay with CachyOS. Packages declared in
`custom.standalone.cachyos.packages` are reconciled by a unit, not installed by
system-manager.

GPU applications resolve EGL and GL through `/run/opengl-driver`. NixOS creates
that path from `hardware.graphics`; CachyOS does not, so the system layer writes
the tmpfiles rule itself and a reboot creates the symlink. Home Manager's
`targets.genericLinux.gpu` is off for the same reason.

A GPU reset can kill the compositor. `amdgpu-coredump` reads the kernel dump
from `/sys/class/devcoredump` and writes it under `/var/lib/amdgpu-coredump`.
The journal is persistent and capped at 1 GB. SDDM autologins Niri at boot;
when a session ends it returns to the greeter, so the Gamescope HDR session can
be selected. A GPU reset therefore costs one login.

### Home Manager on massive

`modules/standalone-linux/home-manager.nix` imports the shared Linux payload
and adds:

- the shared, Linux, and standalone package lists;
- container policy files under `~/.config/containers` because CachyOS ships no
  podman policy;
- a Steam wrapper that clears the Nix library path and uses host tools;
- session variables, including `BROWSER`, `QT_QPA_PLATFORMTHEME`,
  `GTK_THEME`, and a pinned Java 21 home for Android builds;
- `targets.genericLinux` with the GPU target off;
- fontconfig defaults that make `sans-serif` resolve to Fira Sans.

The system-manager switch and the Home Manager switch are separate:

```bash
nix run github:numtide/system-manager -- switch --flake .#massive --sudo
nix run .#home-switch
```

### Gaming

Game launchers stay host-native. Steam and Heroic come from CachyOS. Hydra is
the pinned Nix AppImage extracted and run on the host, with its
`resources/umu-run` helper pointed at the host `umu-launcher`, so games use the
host Vulkan driver instead of the Nix Mesa tree.

```bash
pid=$(pgrep -f 'LOP-Win64-Shipping.exe' | head -1)
grep -E 'libvulkan_radeon|mesa' /proc/"$pid"/maps | head
```

A game process that names `/nix/store/*-mesa-*` is still on the old path.

`game-trainer` reads the running game's environment and starts a trainer or
Cheat Engine in that Wine or Proton prefix. Create the writable config once,
then name entries in `~/.config/game-trainer/games.conf`:

```ini
[LOP-Win64-Shipping.exe]
trainer=/home/mei/Downloads/Lies of P v1.2-v1.8 Plus 25 Trainer.exe
```

With the game running, press `Super+ALT+T`. Cheat Engine needs Yama
`ptrace_scope = 0`; the system layer writes
`/etc/sysctl.d/99-gaming-ptrace.conf`. Apply a sysctl change with
`sudo sysctl --system` or `sudo systemctl restart systemd-sysctl.service`.
A reboot also applies it.

`gaming-health` prints Vulkan details, the Nix driver tree, Niri outputs, and
detected games after a host update. Snap-pac, snapper, and limine-snapper-sync
create and expose pre-update snapshots. A failed graphics update is rolled back
from the pre-update Limine entry before trying again.

Trainers and Cheat Engine are for single-player offline games. Online and
anti-cheat games are not supported.

### HDR output

The Dell S3422DWG on this host is an HDR10 panel. Its EDID advertises the SMPTE
ST 2084 EOTF and HDR static metadata, so the monitor accepts HDR10 over
DisplayPort. Niri 26.04 has no HDR output and no color management, which means
the normal desktop and every Niri application stay SDR.

`pkgs/gamescope-hdr-session.nix` adds a `Gamescope HDR` session to SDDM. It
hands the monitor to the host gamescope with `--backend drm`, `--hdr-enabled`,
and `--hdr-itm-enabled`, then starts the host Steam in Big Picture. The session
exports the variables that let games see HDR:

```bash
ENABLE_GAMESCOPE_WSI=1
DXVK_HDR=1
STEAM_GAMESCOPE_HDR_SUPPORTED=1
STEAM_GAMESCOPE_FORCE_HDR_DEFAULT=1
STEAM_GAMESCOPE_FORCE_OUTPUT_TO_HDR10PQ_DEFAULT=1
STEAM_GAMESCOPE_COLOR_MANAGED=1
```

To use it, log out, pick `Gamescope HDR` at the SDDM greeter, and open a game
that has an HDR option. Games that support HDR detect it through DXGI and the
gamescope WSI layer; other Vulkan applications launched from that session share
the layer. Enable the monitor's HDR preset in its OSD if it is not automatic.
The session drives the `DP-1` connector; edit the package if the monitor moves
to another output.

HDR is limited to that session. Applications in a Niri session cannot use HDR
until Niri implements color management.

## The desktop session

Niri is the compositor and Noctalia is the single authority for the bar,
notifications, screen lock, and wallpaper. The session does not start a second
shell, bar, notification daemon, wallpaper daemon, or lockscreen. The retired
surfaces are Dunst, Polybar, Waybar, Mako, Rofi, Picom, BSPWM, SXHKD, i3lock,
and awww/swww.

- The Noctalia aspect imports the upstream NixOS and Home Manager modules.
  `modules/nixos/files.nix` remains the single owner of the NixOS
  `config.toml`.
- Niri's lock binding calls `noctalia msg screen-lock`.
- The standalone unit sets `X-SwitchMethod=keep-old`, so a Home Manager switch
  leaves the running shell alone. The new unit takes over at the next session
  or service start.
- The config sets `launch_apps_as_systemd_services = true`, so applications
  started from Noctalia run in their own units rather than in the shell's
  cgroup.

External monitor brightness uses DDC/CI. `modules/standalone-linux/openrgb.nix`
writes `/etc/modules-load.d/i2c-dev.conf` and udev rules with `uaccess`, and the
Noctalia config enables `enable_ddcutil`. Check it with:

```bash
ls /dev/i2c-*
ddcutil detect
```

Do not restart Niri or Noctalia just to test DDC access. Toggle the brightness
setting in the Noctalia UI if it needs a refresh.

The login screen differs per system: NixOS uses the Noctalia greeter through
greetd, and massive uses SDDM with the Thyx theme.

## Applications, media, and browsers

The package lists are the source of truth. `modules/shared/packages.nix` covers
cross-platform tools, `modules/linux/packages.nix` covers Linux desktop
applications, `modules/nixos/packages.nix` covers NixOS-only tools,
`modules/standalone-linux/packages.nix` covers the CachyOS host, and
`modules/darwin/packages.nix` covers macOS. `zix` manages package-list edits
through the manifest.

- Zen Browser runs from the `zen-browser` flake input with a declarative profile
  fragment. Spaces, pins, settings, and policies stay declarative; cookies,
  history, sessions, and extension state do not.
- Helium comes from the `helium` input through `pkgs/helium.nix`. The wrapper
  replaces the AppImage's bundled fontconfig with the Nix one and points it at a
  generated `FONTCONFIG_FILE`. The bwrap sandbox binds the host `/etc/fonts` but
  replaces `/usr`, so a foreign distro resolves browser UI text to whichever
  font fontconfig finds first; on CachyOS that was an icon font. Both browser
  profiles stay unmanaged.
- Luciole is the Noctalia Wayland file manager. The `luciole` aspect installs
  the upstream Home Manager module on the Linux hosts. The Linux package list
  also carries its runtime helpers: `ffmpegthumbnailer` for video thumbnails,
  `poppler-utils` for PDF thumbnails, `_7zz` for encrypted archives, and
  `xdg-terminal-exec` for terminal actions. NixOS enables gvfs for Trash and
  network locations.
- `uv` is in the shared package list, so every host has it.
- Calibre has a split: preferences such as save-to-disk templates and
  metadata-source behavior are managed files under `~/.config/calibre`, while
  files that carry machine paths, UUIDs, or history stay outside Home Manager.
  Install the private ones manually with `install -m 0600`.
- Kavita's appsettings are not committed. Keep the real file in an ignored
  local tree and install it by hand; the tracked template is
  `modules/standalone-linux/templates/kavita-appsettings.example.json`.

## Secrets, SSH, and signing

One ed25519 keypair is the GitHub identity of the fleet. The private half is
escrowed in `secrets/github-ssh.yaml`, represented by the `&github` age
recipient in `.sops.yaml`, and installed as `~/.ssh/id_github` (0600) by Home
Manager activation. The public half is `lib/keys.nix`'s `github` entry. The
NixOS and Darwin hosts authorize that key for the user and root; the distro
authorizes nothing.

The age identity that decrypts the store is `~/.config/sops/age/keys.txt`, or
`$SOPS_AGE_KEY_FILE`. A new machine needs that file before the first switch.
Without it the activation warns and leaves `~/.ssh` untouched. The store must be
committed for evaluation to see it. The same key is `sops.age.sshKeyPaths` on
NixOS and Darwin, derived from `~/.ssh/id_ed25519`.

Rotation touches three places: `lib/keys.nix`, the sops store, and the GitHub
registration. Re-derive the recipient with `ssh-to-age < ~/.ssh/id_github.pub`,
reseal the store, update the public key, register the new half with `gh ssh-key
add`, delete the old entry, then switch every host.

Git signing uses a per-machine key generated once by activation. The public half
goes to `~/.ssh/allowed_signers`, and `gpg.ssh.allowedSignersFile` points there.
Commits are SSH-signed.

A fresh host also needs `github.com` in `~/.ssh/known_hosts` before
`git pull` works over SSH. There is no managed known_hosts; run
`ssh -T git@github.com` once and accept the host key.

The full sops workflow and recipient list live in `secrets/README.md`.

## Updates and switches

`nix run .#update` refreshes the flake inputs and then runs the repository-local
updaters. The local updater covers the Linux Home Manager theme sources
(`garuda-dr460nized`, `beautyline`, and `candy-icons`) and rewrites their commit
URLs and hashes in `modules/linux/home-manager.nix`.

```bash
nix run .#update                                # inputs plus theme pins
nix run .#update -- nixpkgs home-manager        # selected inputs
nix run .#update -- --flake-only                # skip the local updaters
nix run .#update -- --local-only --package linux-home-sources
```

After a nixpkgs bump, keep the distro in step. `distro/flake.nix` pins the fleet
revision explicitly because a path input carries no lock of its own:

```bash
# after the root flake.lock moved to a new nixpkgs rev:
# set nixpkgs.url in distro/flake.nix to that rev, then
cd distro && nix flake update nixos-config
```

Several bumps need a follow-up:

- New untracked files are invisible to a `git+file` flake. Stage a new aspect
  or module with `git add` before `nix build` or `nix flake check` can see it.
- `cargoUseSystemLibs` now drives every Rust build. When a package's dependency
  tree needs a system library the package does not declare, add the input to
  `rustSystemLibsOverlay` in `lib/nixpkgs.nix`.
- The theme updater records hashes for the archived theme trees. If a different
  machine records values that do not match the archives served here, re-run the
  local updater and commit the reproducible values.
- nixpkgs can mark a propagated dependency insecure. The current audited
  exception is `python-jose` through `glances`; keep the policy assertion in
  `tests/dendritic-config-eval.nix` in step.

### Switches

```bash
nix run .#build              # build the current host, change nothing
nix run .#build-switch       # NixOS: nh os switch; Darwin: darwin-rebuild switch
nix run .#home-switch        # standalone Home Manager only
nix run .#nh -- os dry-build # print the activation diff
nix run .#home-news          # Home Manager news for the current generation
nix run .#search-pkgs -- gdb # search stable and unstable nixpkgs
nix run .#clean              # drop generations older than seven days
```

The bare `home-manager news` command reads `~/.config/home-manager/home.nix`,
which this standalone configuration does not use. `nix run .#home-news` passes
`--flake` and the current host for you; `home-manager news --flake
<checkout>#massive` is the same call by hand.

`build` and `build-switch` infer the current hostname and refuse to fall back to
another host. `home-switch` selects the only standalone home. `zix switch HOST`
wraps the same commands, and `zix check` runs the quick suite.

### Checks

```bash
nix flake check --all-systems --no-build
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-apps.sh
bash tests/dendritic-shells.sh
bash tests/script-args.sh
bash tests/prose.sh
bash tests/zix.sh
nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'

cd distro
nix flake check
nix build .#checks.x86_64-linux.installer-disk-vm
```

`nix run .#build` is the full local build check. `nix run .#agent-settings`
renders the merged agent rules, and `bash tests/prose.sh` enforces the prose
rules for every markdown and Nix file.

## The distro flake

`distro/` owns one live ISO and one installed profile. Both extend the real
`remembrance` workstation configuration; the distro is not a second desktop
role.

- `nixosConfigurations.installed` adds the distro identity and a mutable user so
  the installer can set a password, then keeps SSH on. The first boot is the
  named host.
- `nixosConfigurations.live` adds a tmpfs root, autologin as the live user,
  passwordless sudo, and turns off the personal keys, Tailscale, Syncthing, and
  label mounts.
- `iso.live` adds the ISO plumbing, the installer packages, the installed
  toplevel, and the flake source.

The installer writes the label contract from the storage section:

- GPT partition 1: 1 GiB, type `EF00`, partlabel `NIXBOOT`, FAT32 label
  `NIXBOOT`;
- GPT partition 2: the remainder, type `8300`, partlabel `NIXROOT`, Btrfs label
  `NIXROOT`;
- Btrfs subvolumes `@root`, `@home`, `@nix`, and `@log`.

### Build and install

```bash
nix build ./distro#iso.live
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

The live ISO needs UEFI, at least 16 GiB, and a non-live disk. Boot the medium,
wait for Niri, and the graphical installer opens. The console installer stays
available:

```bash
sudo nixos-install-tui
sudo nixos-install-tui --list-disks            # JSON list of eligible disks
sudo nixos-install-tui --test --disk /dev/vdb  # stop after the mounts
```

The installer rejects read-only disks, the live medium, USB transports, zram,
device-mapper devices, and disks below 16 GiB. It creates the partitions and
subvolumes, runs `nixos-install --system` against the prebuilt installed
closure, sets the password, copies the flake source to `/etc/nixos`, and
unmounts. No network is needed.

Existing hosts use the same labels. Relabel root and ESP once before switching:

```bash
sudo btrfs filesystem label / NIXROOT
boot_dev=$(findmnt -no SOURCE /boot)
sudo umount /boot
sudo fatlabel "$boot_dev" NIXBOOT
sudo mount /boot
```

Two disks with `NIXROOT` make the boot ambiguous, so keep one system disk per
machine. A missing label drops the boot to emergency mode; relabel from the live
medium or install again.

After the install, rebuilds run from the target's `/etc/nixos` checkout:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#remembrance
```

or use `nix run .#build-switch` from that checkout.

The distro does not cover LUKS2, Secure Boot, persistence or vaults, public
release hardening, a generic username, or the MeccanicOS extras.

## Tests and checks

| Check | What it pins |
| --- | --- |
| `tests/dendritic-architecture.sh` | flat aspects, entity shape, no machine authority, distro boundary |
| `tests/dendritic-boundaries.sh` | identity sources, no disk IDs, retired desktop stack |
| `tests/dendritic-apps.sh` | app inventory and the app wrapper contract |
| `tests/dendritic-shells.sh` | Nushell and Bash resolve to store paths |
| `tests/dendritic-config-eval.nix` | host evaluation, packages, policy, and the one insecure exception |
| `tests/script-args.sh` | `build-switch` host default and argument pass-through |
| `tests/prose.sh` | prose rules from `tools/check-prose.py` |
| `tests/zix.sh` | zix unit, fixture, and offline smoke tests |
| `distro/tests/config-eval.nix` | installed, live, and ISO contracts |
| `distro/tests/installer-disk-vm.nix` | partitioning and labels on a blank virtual disk |

The agent rules live in `agent-settings.nix` and are rendered by
`nix build .#agent-settings`. Read `AGENTS.md` before editing the repository.

## Known limits

- The distro is unverified on Secure Boot and LUKS2, and the live/installed
  profiles trust no personal SSH key until an operator adds one.
- `freecad` is paused until its dependency compiles against the pinned boost.
- ZFS is unused. The explicit `forceImportRoot = false` keeps nixpkgs quiet.
- A store link for `~/.ssh/config` fails inside user namespaces. Activation
  replaces it with a private copy; `git push` from an FHS wrapper or sandbox
  then works.
- Nix flake evaluation reads tracked files only. Stage new files before
  building.
- HDR is only available in the Gamescope HDR session. Niri has no HDR output or
  color management, so the normal desktop stays SDR.
- macOS app bundle appearance and the first Darwin activation are checked by
  hand; the darwin-uninstaller is disabled until its manual renderer matches
  nix-darwin.

## History

The repository started as a Flat or dendritic config for the two workstations,
then absorbed the macOS host. The April 2026 audit of the CachyOS laptop decided
which packages stay host-native and which move into Home Manager and a small
system-manager layer; that layer is the reason `massive` has no NixOS
configuration. The October 2026 tooling review brought nixpkgs-multiverse pins
and produced `zix`, which now owns the managed package set and its tests. The
current tree keeps those decisions: no machine authority, one label contract,
and one policy file for keys, caches, unfree names, and overlays.
