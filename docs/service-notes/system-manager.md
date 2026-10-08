# system-manager on the standalone host

`massive` (the CachyOS ThinkPad) is the only non-NixOS machine in this repo.
Home Manager owns its user payload. The `system-manager` layer owns the small
amount of system state that Home Manager cannot reach there, because a foreign
distribution keeps `/etc` and the systemd system units out of reach.

## What the layer owns

`flake.systemConfigs.massive`, built by `modules/flake/system-manager.nix` from
`modules/standalone-linux/system.nix`:

- the static hostname, applied to the file, the kernel, and systemd-hostnamed by
  a `hostnamectl set-hostname massive` oneshot; and
- `tailscaled`, from `pkgs.tailscale`, on the same socket and state paths that
  the distribution package used, with `systemd.tmpfiles` rules creating
  `/var/lib/tailscale` and `/run/tailscale`. An existing node identity therefore
  carries over without a second login.

Nothing else. The kernel, the bootloader, the package manager, and the desktop
stay with CachyOS.

## Applying it

From a checkout on the host:

```bash
nix run github:numtide/system-manager -- switch --flake .#massive --sudo
```

`--flake .#massive` resolves `systemConfigs.massive`; system-manager prefixes the
attribute with `systemConfigs` itself, so the bare host name is what it wants. A
bare `--flake .` tries the running hostname first and then `default`, so it also
lands on `systemConfigs.massive` once the hostname is `massive`.

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
layer owns (one `/etc` file, systemd units, tmpfiles rules) is
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
