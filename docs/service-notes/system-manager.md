# system-manager on the standalone host

`massive` (the CachyOS ThinkPad) is the only non-NixOS machine in this repo.
Home Manager owns its user payload. The `system-manager` layer owns the small
amount of system state that Home Manager cannot reach there, because a foreign
distribution keeps `/etc` and the systemd system units out of reach.

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
  cache union from `lib/nix-caches.nix`; and
- the 970 EVO data disk, as a mount unit for `LABEL=970EVO` at `/mnt/970` plus a
  oneshot that gives the desktop user ownership of the filesystem root.

The kernel, the bootloader, the package manager, and the desktop stay with
CachyOS.

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
