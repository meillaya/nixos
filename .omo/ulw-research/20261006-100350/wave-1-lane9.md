# Wave 1 — lane9 (repo dive: nixos-anywhere + disko source)

Pins: nixos-anywhere 3c6e0cc (version 1.13.0 + 1 commit), disko 725ea35 (version.nix 1.13.0,
released=false). Note: "single-gpt-btrfs" is this repo's own profile name, not upstream.

## Deals (quoted from the pinned source)

- nixos-anywhere drives disko's NixOS-MODULE outputs, never the disko CLI:
  `diskoAttr = ${diskoMode}Script` (`diskoScript`/`formatScript`/`mountScript`, +NoDeps variants),
  built as `${flake}#${flakeAttr}.system.build.${diskoAttr}` and run over SSH.
- `system.build.diskoScript` = `_legacyDestroy + _create + _mount`; `_legacyDestroy` has NO wipe
  confirmation ("Does not ask for confirmation! Deprecated in favor of _destroy") — so the ONLY
  confirmation in our flow is the app's `--yes` gate and the live-root guard. Confirmed.
- `disko --mode destroy,format,mount` (the CLI): `_destroy` prompts unless --yes-wipe-all-disks, then
  `disk-deactivate` per disk = `wipefs --all -f <dev>` + `dd if=/dev/zero bs=440 count=1`, then
  `sgdisk --clear`, fresh `mkfs.btrfs`, subvolumes recreated EMPTY. There is NO `btrfs subvolume
  delete` anywhere in disko — subvolumes die with the filesystem signature. Irreversible.
- `--mode format,mount` (no destroy) is the idempotent, non-destructive path: skips mkfs when
  `blkid` reports TYPE=btrfs and only creates missing subvolumes. This is what nixos-anywhere's
  `--disko-mode mount|format` relies on (and the documented repair path).
- This repo's disk layout (modules/nixos/disk-config.nix): ESP vfat 1024M -> /boot; single GPT disk,
  btrfs `-f`, subvolumes `@root -> /`, `@home -> /home`, `@nix -> /nix`, `@log -> /var/log`,
  compress=zstd:3 noatime; mounted with `subvol=<name>` + `X-mount.mkdir`.
- disko-install builds `installToplevel + closureInfo + <mode>Script` via install-cli.nix
  (extendModules with `disko.rootMountPoint`), runs the script with `DISKO_SKIP_SWAP=1`, `cp -ar`
  extra-files, seeds the store when the target DB is empty, then `nixos-install --root <mountPoint>`
  (default /mnt/disko-install-root). No destroy mode exists in disko-install.

## Contradictions surfaced

1. Help text/reference list `--disko-mode destroy`, but the parser accepts only
   `format|mount|disko` and aborts otherwise (documented-but-rejected).
2. docs/reference says the default kexec image is x86_64-only; code supports x86_64|aarch64.
3. extra-files "after installation" (docs) vs before nixos-install (code) — third independent
   confirmation of the doc bug.
4. Destructive-prompt asymmetry: nixos-anywhere's default diskoScript never prompts; only the CLI
   reaches the prompting `_destroy`.

## Consequence for the design

- The app's `--yes` + live-root guard are load-bearing: nixos-anywhere itself will silently wipe.
- A no-wipe "read the old disk" step needs no disko at all (manual mount -o ro).
- If the design ever switches to disko-install, the silent-continue bug (#1046) plus the no-prompt
  disko script becomes a two-layer safety hazard.
