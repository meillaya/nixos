# Gaming stability on the standalone host

The game launchers are host-native. Steam and Heroic are CachyOS packages.
Hydra is the pinned Nix AppImage extracted and run on the host, with its
`resources/umu-run` helper pointed at the host `umu-launcher`. Games therefore
use the host Vulkan driver, not the Nix `/run/opengl-driver` tree.

Check a running game from another terminal:

```bash
pid=$(pgrep -f 'LOP-Win64-Shipping.exe' | head -1)
grep -E 'libvulkan_radeon|mesa' /proc/"$pid"/maps | head
```

The line should name `/run/host/usr/lib/libvulkan_radeon.so` or another host
path. A line naming `/nix/store/*-mesa-*` in a game means the launcher is still
on the old path.

## Trainers and Cheat Engine

`game-trainer` finds the active Wine/Proton game from the process environment,
then starts a trainer or Cheat Engine in that prefix. It works for Steam,
Heroic, Hydra, and other Wine launchers.

Create the writable config with `game-trainer --init`, then configure one game
in `~/.config/game-trainer/games.conf`:

```ini
[LOP-Win64-Shipping.exe]
trainer=/home/mei/Downloads/Lies of P v1.2-v1.8 Plus 25 Trainer.exe
```

For Cheat Engine:

```ini
[SomeGame.exe]
cheat_engine=/home/mei/.nix-profile/share/cheat-engine/cheatengine-x86_64
table=/home/mei/Downloads/SomeGame.CT
```

The packaged Cheat Engine is the Linux build. Point the config at its
`share/cheat-engine/cheatengine-x86_64`, not the `bin/cheat-engine` wrapper,
so the helper can copy the tree to a writable cache and install the auto-attach
Lua script. A Windows Cheat Engine executable in a Wine prefix also works.

Press `Super+ALT+T` with the game running. The helper uses the focused Niri
window when possible, otherwise the largest game process. It sets
`GAME_TRAINER_GAME` and `GAME_TRAINER_PID` and installs a small autorun Lua
script beside Cheat Engine so the table can attach to that process. There is no
custom picker UI.

## Session recovery

`/etc/sddm.conf.d/10-gaming-autologin.conf` sets SDDM to log `mei` back into
niri after the session ends. A GPU reset still destroys the old session and any
unsaved application state; autologin only restores the desktop automatically.

`amdgpu-coredump` saves a reset dump under `/var/lib/amdgpu-coredump`. The
journal is persistent and capped at 1 GB. Inspect a reset with:

```bash
journalctl -b -k | grep -E 'ring .* timeout|VRAM is lost'
sudo ls -lh /var/lib/amdgpu-coredump
```

## Updates and rollback

`snapper`, `snap-pac`, and `limine-snapper-sync` are installed. Snap-pac creates
pre and post snapshots for pacman transactions, and Limine exposes the matching
boot entries.

Use `tools/gaming-update` for Nix inputs. It updates a temporary copy, builds the
system and Home Manager layers, runs the repository checks, and only then
replaces `flake.lock`. A failing update leaves the real lock alone.

After a pacman update, run:

```bash
gaming-health
```

It prints Vulkan details, the Nix driver tree, Niri outputs, and detected games.
If a host update breaks graphics, boot the pre-update Limine snapshot and roll
the filesystem back before updating again.

## Limits

A full GPU reset is a kernel and firmware event. It cannot be prevented by a
launcher, a trainer, or a userspace daemon. This setup removes the known Nix
driver skew, captures the dump, and restores the desktop after the crash. If
resets continue on the host driver, test the installed `linux-cachyos-lts`
kernel; if they continue there, the remaining cause is the driver, firmware, or
hardware.

Trainers and Cheat Engine are for single-player, offline games. Anti-cheat and
online games are unsupported.
