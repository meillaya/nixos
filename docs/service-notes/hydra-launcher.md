# Hydra game launching on the standalone host

`hydralauncher` comes from `modules/linux/packages.nix`. The nixpkgs package is
a wrapped AppImage inside `buildFHSEnv`, which hides the CachyOS `/usr` and
makes the game path use the Nix Mesa tree. That tree does not match the host
driver and has caused hangs and a broken Vulkan device.

## Fix in this repo

`pkgs/hydralauncher.nix` runs the extracted AppImage on the host instead:

- Hydra starts with the host Electron libraries and host `/usr/bin`; and
- `resources/umu-run` is replaced with a small Python launcher that execs the
  host `/usr/bin/umu-run`.

The game process therefore uses the host Vulkan driver, the same driver as
Steam and Heroic. The previous FHS package is kept in
`pkgs/hydralauncher-fhs.nix` for rollback.

`modules/linux/packages.nix` uses the host package. The host package set adds
`winetricks`, `mangohud`, `gamemode`, and `lib32-gamemode`, so Hydra, Steam,
and native launchers see the same tools.

## Applying it

```bash
cd /home/mei/nixos
nix run github:numtide/system-manager -- switch --flake .#massive --sudo
nix run .#home-switch
```

The system-manager switch installs the host gamemode packages. The Home Manager
switch replaces Hydra with the patched build. Restart Hydra afterwards.

## Updating Hydra

`pkgs/hydralauncher.nix` does not pin a Hydra version. It reads `pname`,
`version`, `contents`, and `meta` from the nixpkgs `hydralauncher` package,
so `nix flake update` moves Hydra and this host wrapper together.

The wrapper makes two assumptions about the AppImage: `resources/umu-run`
exists, and Hydra starts the extracted `hydralauncher` Electron binary. If an
upstream release moves the bundled umu-run, the build fails at the
`resources/umu-run` write and the wrapper needs that path updated.

The first umu launch may download the Steam Linux Runtime into
`~/.local/share/umu` (about 195 MB). Later launches reuse it.

## Trainers and Cheat Engine

`game-trainer` launches a Windows trainer or Cheat Engine in the active Wine
or Proton game prefix. It does not care whether the game came from Hydra,
Steam, or Heroic. It reads the game's own environment, so it uses the same
prefix, Wine binary, and fsync settings. It does not create a second prefix.

Create the writable config with `game-trainer --init`, then add one entry to
`~/.config/game-trainer/games.conf`:

```ini
[LOP-Win64-Shipping.exe]
trainer=/home/mei/Downloads/Lies of P v1.2-v1.8 Plus 25 Trainer.exe
```

Press `Super+ALT+T` with the game running. The configured trainer starts
against the active game. The same command works from a terminal:

```bash
game-trainer
game-trainer '/path/to/trainer.exe'
game-trainer --game 'LOP-Win64' '/path/to/trainer.exe'
```

Useful options:

```bash
game-trainer --list              # show detected games, prefixes, and tools
game-trainer --wait              # wait for a game to start
game-trainer --game Lies         # choose a game by process name
```

For Cheat Engine, configure the engine and table:

```ini
[SomeGame.exe]
cheat_engine=/path/to/cheatengine-x86_64.exe
table=/path/to/SomeGame.CT
```

The helper selects the focused game window when possible, otherwise the
highest-memory game process. It ignores Wine infrastructure and running
trainers. There is no separate picker window; the config is the one place to
name a trainer.

## Verification

The compatibility section in Hydra should report Winetricks, MangoHud, and
GameMode as available. Launching `/mnt/970/Games/Lies of P/LOP.exe` through
Hydra should start the same Proton prefix that works outside the launcher.

If the launch still fails, read:

```text
~/.config/hydralauncher/logs/umu.log
~/.config/hydralauncher/logs/info.txt
```
