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

## One-time OS setup for existing non-NixOS Linux

Standalone Home Manager cannot safely own `/etc` kernel-module and udev files.
For an existing Arch/CachyOS-style install, perform the root-level setup
explicitly using the host distribution's normal administration workflow:

```bash
sudo modprobe i2c-dev
echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf
sudo groupadd -f i2c
sudo usermod -aG i2c "$USER"
printf 'KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660", TAG+="uaccess"\n' \
  | sudo tee /etc/udev/rules.d/70-i2c.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Log out and back in after adding your user to the `i2c` group. These commands
are operational guidance only; this repository did not execute or verify them
on a live standalone machine.

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
