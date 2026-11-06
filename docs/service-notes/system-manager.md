# system-manager on the standalone host

`massive` (the CachyOS ThinkPad) is the only non-NixOS machine in this repo.
Home Manager owns its user payload. The `system-manager` layer owns the system
state that Home Manager cannot reach there, because a foreign distribution keeps
`/etc`, the systemd system units, the pacman database, and the login shell out of
Home Manager's reach.

## What the layer owns

`flake.systemConfigs.massive`, built by `modules/flake/system-manager.nix` from
`modules/standalone-linux/system.nix`:

- the static hostname, applied to the file, the kernel, and systemd-hostnamed by
  a `hostnamectl set-hostname massive` oneshot;
- `tailscaled`, from `pkgs.tailscale`, on the same socket and state paths that
  the distribution package used, with `systemd.tmpfiles` rules creating
  `/var/lib/tailscale` and `/run/tailscale`;
- `/run/opengl-driver`, a symlink to a `buildEnv` of Mesa, libglvnd, and the
  VA-API drivers, created by a `systemd.tmpfiles` rule;
- `/etc/nix/nix.custom.conf`, with `trusted-users = root @wheel` and the signed
  cache union from `lib/nix-caches.nix`;
- the 970 EVO data disk, as a mount unit for `LABEL=970EVO` at `/mnt/970` plus a
  oneshot that gives the desktop user ownership of the filesystem root;
- the login account record, its Nushell login shell, and `/etc/shells`;
- the `/run/wrappers/bin/unix_chkpwd` PAM helper;
- the CachyOS pacman package bootstrap and fish removal in
  `modules/standalone-linux/cachyos.nix`;
- the Thyx SDDM theme selection and its Qt6 packages; and
- OpenRGB and its generated udev rules in `modules/standalone-linux/openrgb.nix`.

The kernel, the bootloader, and the rest of the package manager stay with
CachyOS. Pacman packages declared here are reconciled by a unit, not installed
by system-manager.

## GPU drivers on a foreign distribution

Nix packages resolve EGL and GL through `/run/opengl-driver`. NixOS creates that
path from `hardware.graphics`; CachyOS does not. Without it, `libglvnd` loads no
EGL vendor and a Nix application exits with `eglGetDisplay failed` before it
draws anything. The application is not broken; the driver path is missing.

Home Manager's `targets.genericLinux.gpu` builds the driver tree but can only
print the `sudo non-nixos-gpu-setup` command that installs the tmpfiles rule,
because the rule lives under `/etc`. `modules/standalone-linux/home-manager.nix`
turns that module off, and `modules/standalone-linux/system.nix` installs the
rule itself. A reboot then recreates the symlink with no manual step.

The old manual setup left two files behind. Remove them once, after the first
switch that includes this layer:

```bash
sudo rm -f /etc/tmpfiles.d/non-nixos-gpu.conf /nix/var/nix/gcroots/non-nixos-gpu.conf
```

The tree follows the nixpkgs Mesa version, while the host desktop follows the
CachyOS Mesa package. Check both before blaming a game for a driver crash:

```bash
nix eval --raw --impure --expr 'let f = builtins.getFlake "path:/home/mei/nixos"; in f.inputs.nixpkgs.legacyPackages.x86_64-linux.mesa.version'
pacman -Q mesa
```

A GPU reset can kill the compositor when Mesa aborts after `VRAM is lost`.
`amdgpu-coredump` is a root watcher for the kernel dump. It reads
`/sys/class/devcoredump/devcd*/data` and writes
`/var/lib/amdgpu-coredump/amdgpu-*.bin`. The data file is root-only and is
consumed when read, so the watcher is a system service rather than a user
script. The dump can be inspected with `sudo ls -l /var/lib/amdgpu-coredump`.

## Nix settings and cache trust

Determinate Nix includes `/etc/nix/nix.custom.conf` from `/etc/nix/nix.conf`, so
the layer writes that include target and leaves the installer's own file alone.
The file grants wheel trust, which is what lets a user-level `nix.conf` add
substituters, and it repeats the cache union so root builds from the same signed
caches.

A running `nix-daemon` reads its settings at start. Restart it once after the
first switch, or reboot:

```bash
sudo systemctl restart nix-daemon
```

## The data disk

The second NVMe disk is an ext4 filesystem labelled `970EVO`, mounted at
`/mnt/970` by a systemd mount unit. The label is the device name, so no UUID or
disk ID enters the repo. `standalone.dataDisk.device` and
`standalone.dataDisk.mountPoint` override the defaults, and
`standalone.dataDisk.enable` gates the mount unit and the ownership service.

The ownership service runs `chown` on the filesystem root only, then sets mode
`0755`. Existing files keep their owners, so a disk moved from another install
keeps its per-file ownership.

## Nushell login shell

`modules/standalone-linux/system.nix` declares the account under `users.users`
with `shell = pkgs.nushell`. system-manager maps a shell package to
`/run/system-manager/sw/bin/nu`, so that exact path must appear in `/etc/shells`.
The PAM stacks on CachyOS include `pam_shells`, which rejects a login shell that
is absent from that file. The layer replaces `/etc/shells` with a managed list
containing `/bin/sh`, `/bin/bash`, and the Nushell profile path.
`replaceExisting = true` makes system-manager keep a backup and restore the
distribution file on deactivation.

The account keeps the UID and supplementary groups the CachyOS installer
created. userborn never changes an existing UID, and because this module declares
no `extraGroups`, existing memberships are preserved. The primary group is the
user-private group at the same gid as the account.

## CachyOS packages and fish removal

system-manager cannot install pacman packages. `modules/standalone-linux/cachyos.nix`
declares the package list and a `cachyos-bootstrap` oneshot. On activation the
unit checks each package with `pacman -Qq`, installs the missing set with
`pacman -S --needed --noconfirm`, then removes any installed package from the
removal list. The default list installs `yay`, `cachyos-gaming-meta`,
`cachyos-gaming-applications`, `wine-mono`, `winetricks`, `mangohud`,
`gamemode`, and `lib32-gamemode`, and removes `fish`, `cachyos-fish-config`,
`fish-autopair`, `fish-pure-prompt`, and `fisher`.

The unit does not run `pacman -Sy` and does not upgrade the host. A missing
package with a stale sync database fails the unit; run a normal system update,
then retry:

```bash
sudo systemctl start cachyos-bootstrap
```

The script exports the distribution `PATH` before it calls pacman. systemd gives
the unit a Nix-only `PATH`, and pacman's gpgme needs to find the host `gpg` to
verify the package databases. Without the export, pacman fails with `GPGME
error: Invalid crypto engine`.

Removing the fish packages leaves `~/.config/fish` alone. User files stay user
files.

## SDDM theme

`modules/standalone-linux/cachyos.nix` installs the pinned Thyx theme from
`pkgs/thyx.nix` and writes
`/etc/sddm.conf.d/00-system-manager-theme.conf` with
`Current=thyx` and `ThemeDir=/run/system-manager/sw/share/sddm/themes`.
The package copies `presets/blush.conf` over `theme.conf`, so the greeter starts
on the Blush preset. The other presets stay installed.

SDDM reads the theme when it starts. Restart it or reboot after the switch:

```bash
sudo systemctl restart sddm
```

The theme imports QtMultimedia and Qt5Compat.GraphicalEffects, so the package
unit also installs `qt6-multimedia`, `qt6-multimedia-ffmpeg`, `qt6-5compat`, and
`qt6-svg`. The greeter runs as the `sddm` user and reads the theme and bundled
Plus Jakarta Sans font from the system-manager profile. A fontconfig fragment
adds `/run/system-manager/sw/share/fonts` to the search path, and a `fc-cache -f`
oneshot refreshes the cache.

Test the greeter from a TTY without restarting the running session:

```bash
sddm-greeter-qt6 --test-mode --theme /run/system-manager/sw/share/sddm/themes/thyx
```

## OpenRGB

`modules/standalone-linux/openrgb.nix` installs `pkgs.openrgb` as a system
package, links its generated `60-openrgb.rules` into `/etc/udev/rules.d`, and
loads `i2c-dev` through `/etc/modules-load.d`. The `openrgb-udev-reload` oneshot
runs `udevadm control --reload-rules` and `udevadm trigger`. The OpenRGB SDK
server is not enabled; the system package exists so standalone OpenRGB can reach
USB and I2C devices through the rules.

## Steam and the Nix PATH

Noctalia starts desktop applications with `systemd-run` and copies its own
environment into the service. The user PATH puts `~/.nix-profile/bin` ahead of
`/usr/bin`, so Steam's shell helpers resolve `dirname` and `basename` to Nix
coreutils. Steam then prepends its runtime to `LD_LIBRARY_PATH`, and Nix
coreutils load the host glibc under that path:

```text
dirname: symbol lookup error: /usr/lib/libc.so.6: undefined symbol: __pointer_chk_guard, version GLIBC_PRIVATE
```

That breaks `steamwebhelper.sh` before it starts the webhelper, which Steam
reports as "steamwebhelper is not responding".

`modules/standalone-linux/cachyos.nix` writes
`/etc/systemd/user/app-steam@.service.d/10-system-manager-path.conf` with a host
PATH for the Steam systemd unit. Noctalia passes its environment with `-E PATH`,
but the unit drop-in takes precedence, so Steam and its helpers use the host
tools. `modules/standalone-linux/home-manager.nix` also installs
`~/.local/bin/steam`, a wrapper that sets the same PATH for launches from a
terminal.

Apply the switch, reload the user manager, then relaunch Steam:

```bash
systemctl --user daemon-reload
```

The terminal wrapper is part of the Home Manager payload. Apply it with
`nix run .#home-switch`, or let the next Home Manager switch install it.

## Lock screen password authentication

Nix-built Noctalia links nixpkgs libpam. Its `pam_unix` module calls
`/run/wrappers/bin/unix_chkpwd`, a path NixOS creates through `security.pam`.
CachyOS has no such path, so the lock screen rejects the correct password.
`modules/standalone-linux/system.nix` declares the same wrapper through
`security.wrappers.unix_chkpwd`. `/run/wrappers` already exists as a
system-manager-managed tmpfs for the mount and umount wrappers, so this adds one
setuid-root file to the same directory.

The `/etc/shells` entry matters here as well. Both the login stack and the
Noctalia lock screen run `pam_shells` before `pam_unix`, so the Nushell profile
path must be listed or authentication fails before the password is checked.
NixOS hosts already get this wrapper and shell list from their own modules; the
standalone host needs the explicit declarations.

If authentication still fails, the journal shows whether nixpkgs libpam rejected
a CachyOS module:

```bash
journalctl --user -u noctalia -b
```

## Applying it

From a checkout on the host:

```bash
nix run github:numtide/system-manager -- switch --flake .#massive --sudo
```

`--flake .#massive` resolves `systemConfigs.massive`; system-manager prefixes the
attribute with `systemConfigs` itself, so the bare host name is what it wants. A
bare `--flake .` tries the running hostname first and then `default`, so it also
lands on `systemConfigs.massive` once the hostname is `massive`.

Activation starts `system-manager.target`. A target that is already active does
not pick up units added by the switch, so start the new mount once, or reboot:

```bash
sudo systemctl start mnt-970.mount
```

The same applies to the bootstrap, udev, and font units on the switch that adds
them. A reboot runs all of them in order. To apply them without a reboot:

```bash
sudo systemctl start cachyos-bootstrap openrgb-udev-reload system-manager-fonts
sudo systemctl restart sddm
```

After the switch, check the parts that affect login and the display manager:

```bash
getent passwd mei
grep -F /run/system-manager/sw/bin/nu /etc/shells
ls -l /run/wrappers/bin/unix_chkpwd
systemctl status cachyos-bootstrap openrgb-udev-reload
ls -l /etc/udev/rules.d/60-openrgb.rules
```

## How the hostname is set

The `set-hostname` unit runs `hostnamectl set-hostname massive`, which is the one
mechanism that updates `/etc/hostname`, the kernel hostname, and
systemd-hostnamed together, and it is idempotent on every later activation.

Two nearby designs do not work here. An `environment.etc."hostname"` entry is
ignored while a regular file already occupies that path, because the engine
replaces only files whose entry sets `replaceExisting`, and the first switch on a
foreign distribution always finds the distribution's own file there. A
transient write is refused as well: `hostnamectl set-hostname --transient`
answers "static hostname is already set, so the specified transient hostname
will not be used", which is exactly what the first attempt on this machine hit.

## CachyOS is an untested distribution

system-manager's pre-activation assertion accepts `nixos`, `ubuntu` and `debian`
only. `system-manager.allowAnyDistro = true` in
`modules/standalone-linux/system.nix` turns that assertion off. Everything this
layer owns (the `/etc` files, systemd units, and tmpfiles rules) is
distribution-neutral, so the opt-out is the whole cost of running on Arch.

## Migrating off the distribution package

The Arch package installs `/usr/lib/systemd/system/tailscaled.service`. A unit
written by system-manager lands in `/etc/systemd/system/tailscaled.service`,
which takes precedence, so the declarative unit wins as soon as the layer is
applied. Removing the package afterwards leaves one daemon and one CLI:

```bash
sudo pacman -Rns tailscale
```

The CLI then comes from the system-manager profile entry in
`/etc/profile.d/system-manager-path.sh`, so source that file or log in again.

If the distribution package is removed while its daemon is still running, that
process keeps the node up with no unit file behind it, so nothing restarts it
after a reboot. The system-manager unit takes the same name and runs
`tailscaled --cleanup` before `ExecStart`, which clears the stale socket and TUN
device, so a plain `systemctl restart tailscaled` after the switch hands the
node over cleanly.
