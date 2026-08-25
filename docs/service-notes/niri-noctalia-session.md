# Niri and Noctalia session safety

Noctalia is the sole configured authority for the Niri bar, notifications,
screen lock, and wallpaper. The shared Niri configuration must not launch a
second shell or wallpaper daemon, and the NixOS-composed Home Manager profile
must not enable a competing bar, notification daemon, or screen locker. The
upstream Noctalia modules own the `noctalia.service` unit, while Niri remains
the compositor without a competing Picom service.

## Ownership

- `den.aspects.noctalia.nixos` imports the upstream NixOS module, which owns the
  package, user service, and recommended NetworkManager, Bluetooth, UPower, and
  power-profile services.
- `den.aspects.noctalia.homeManager` imports the upstream Home Manager module,
  which owns the standalone package, validated TOML, and user service.
- The upstream NixOS module has no settings option, so
  `modules/nixos/files.nix` remains the single NixOS config-file owner.
- Legacy Dunst, Polybar, Home Manager screen-locker, i3lock, Picom,
  BSPWM/SXHKD/Rofi, standalone Waybar/Mako, and `awww`/`swww` startup surfaces
  are absent from the composed Niri session.
- Niri invokes `noctalia msg screen-lock` for its lock binding. Noctalia's TOML
  enables its bar, notification daemon, and wallpaper surfaces.

The standalone unit sets `X-SwitchMethod=keep-old`. Home Manager's `sd-switch`
therefore leaves an already-running Noctalia process untouched during a switch;
the new unit is used at the next deliberate session/service start instead of
restarting the live desktop shell during activation.

The declarative TOML also sets:

```toml
[shell]
launch_apps_as_systemd_services = true
```

Applications started from Noctalia are placed in their own systemd services
rather than inheriting the Noctalia service cgroup. Stopping or failing the shell
therefore does not take launcher children down with it.

## Build-safe verification

Do not test this policy with a live Home Manager switch or a service restart.
Use evaluation and dry-run surfaces only:

```bash
nix eval --raw .#homeConfigurations.standalone-linux.activationPackage.drvPath
nix-instantiate --eval --strict --expr \
  'import ./tests/dendritic-config-eval.nix {}'
bash tests/dendritic-architecture.sh
nix flake check --all-systems --no-build
git diff --check
nix run .#home-switch -- --dry-run
```

These commands prove repository evaluation and dry-run behavior only. They do
not prove a live Niri session, service state, lock screen, notification delivery,
or wallpaper rendering.

After a separately scheduled logout/login, status and logs may be inspected
without restarting the service:

```bash
systemctl --user status noctalia.service --no-pager
journalctl --user -u noctalia.service -b --no-pager
```
