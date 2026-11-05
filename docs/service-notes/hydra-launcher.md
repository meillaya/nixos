# Hydra game launching on the standalone host

`hydralauncher` comes from `modules/linux/packages.nix`. The nixpkgs package is
a wrapped AppImage, and `appimageTools` runs it inside `buildFHSEnv`. Hydra sees
the FHS `/usr/bin`, not CachyOS `/usr/bin`, so the host `winetricks` and
`mangohud` binaries are invisible to its PATH checks. `gamemoderun` was also
missing from the host package set.

The same isolation affects game launches. Hydra bundles its own `umu-run` 1.3.0
in `resources/umu-run`. That version fails to install the Steam Linux Runtime:

```text
ERROR: Digest mismatched: SteamLinuxRuntime_sniper.tar.xz
FileNotFoundError: _v2-entry-point (umu) cannot be found in '/home/mei/.local/share/umu/steamrt3'
```

The host `umu-run` 1.4.3 installs the runtime correctly, so the bundled 1.3.0
is the problem.

## Fix in this repo

`pkgs/hydralauncher.nix` builds the same Hydra release with two changes:

- the FHS environment adds `winetricks`, `mangohud`, and `gamemode` from
  nixpkgs, so Hydra's availability checks and command wrappers find them; and
- `resources/umu-run` is replaced with a small Python launcher that execs
  `/usr/bin/umu-run` from the FHS environment, which is the current
  `umu-launcher-unwrapped` 1.4.4.

`modules/linux/packages.nix` uses that package instead of the nixpkgs Hydra.
`modules/standalone-linux/cachyos.nix` adds `winetricks`, `mangohud`,
`gamemode`, and `lib32-gamemode` to the host package set, so Steam and native
launchers see the same tools.

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
`version`, `contents`, `extraInstallCommands`, and `meta` from the nixpkgs
`hydralauncher` package, so `nix flake update` moves Hydra and this FHS wrapper
together.

The wrapper makes two assumptions about the AppImage: `resources/umu-run`
exists, and Hydra still checks `winetricks`, `mangohud`, and `gamemoderun` on
PATH. If an upstream release moves the bundled umu-run, the build fails at the
`resources/umu-run` write and the wrapper needs that path updated. If Hydra
replaces its launcher checks, the FHS package list may need a matching change.

The first umu launch may download the Steam Linux Runtime into
`~/.local/share/umu` (about 195 MB). Later launches reuse it.

## Verification

The compatibility section in Hydra should report Winetricks, MangoHud, and
GameMode as available. Launching `/mnt/970/Games/Lies of P/LOP.exe` through
Hydra should start the same Proton prefix that works outside the launcher.

If the launch still fails, read:

```text
~/.config/hydralauncher/logs/umu.log
~/.config/hydralauncher/logs/info.txt
```
