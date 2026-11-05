# Noctalia external monitor brightness on standalone Linux

Noctalia uses `brightnessctl` for internal backlights and `ddcutil` over
DDC/CI for external monitor brightness. On this machine the Noctalia settings
were already the right place to fix the UI, but the OS still had to expose the
I2C device nodes that `ddcutil` needs.

## Symptoms

- Noctalia Display settings showed monitor brightness sliders, but changing
  them did not change external monitor brightness.
- `~/.config/noctalia/config.toml` did not originally enable Noctalia's
  `ddcutil` integration.
- `/sys/class/backlight` was empty, which is expected for external monitors.
- `ddcutil detect` failed with:

```text
No /dev/i2c devices exist.
ddcutil requires module i2c-dev.
```

## Fix in this repo

The Home Manager-managed Noctalia v5 configuration now enables DDC brightness:

- `modules/standalone-linux/config/noctalia/config.toml`
  - `[brightness]`
  - `enable_ddcutil = true`

The standalone Linux package set includes `ddcutil`:

- `modules/standalone-linux/packages.nix`

The NixOS host config also enables I2C access declaratively:

- `modules/nixos/system.nix`
  - `hardware.i2c.enable = true`
  - user is in `i2c` and `video`

## Root-level setup on standalone Linux

`modules/standalone-linux/openrgb.nix` now owns the root-level I2C setup through
system-manager. It writes `/etc/modules-load.d/i2c-dev.conf` and installs the
OpenRGB udev rules, whose I2C rule grants the active session access with
`TAG+="uaccess"`. The `openrgb-udev-reload` oneshot runs `udevadm control
--reload-rules` and `udevadm trigger`. No `i2c` group membership is needed, and
no manual file under `/etc` is required.

Apply the layer and let the unit run:

```bash
nix run github:numtide/system-manager -- switch --flake .#massive --sudo
sudo systemctl start openrgb-udev-reload
```

A reboot also loads `i2c-dev` through systemd-modules-load.

## Verification

After setup, these commands should show I2C device nodes and detected displays:

```bash
ls /dev/i2c-*
ddcutil detect
```

If `ddcutil detect` reports that a display does not support DDC/CI, enable
DDC/CI in that monitor's physical on-screen menu.

Avoid restarting Niri or Noctalia just to verify DDC access. Once `ddcutil
detect` works, use Noctalia Display settings; if Noctalia needs a refresh,
toggle the external monitor brightness setting off and on from the UI.
