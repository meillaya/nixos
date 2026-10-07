# Ultrawork Notepad — A4: machine0 image lifecycle + slimming/speed levers (m0-coding)
[APPENDED 2026-10-07 — measurements complete]

## MEASURED (this session, local workstation)
- Evaluated `x86_64-linux` coding system; environment.systemPackages = 189 entries.
- Runtime-closure union of the 189 syspkgs' `nix path-info --store <cache> -r` closures
  (cache.nixos.org + machine0.cachix.org + deepseek-harness-nix.cachix.org + devenv.cachix.org)
  = 822 store paths, **7.70 GiB (8.27 GB)**. Excludes 6 packages no cache holds:
  claude-code-2.1.214, machine0-cli-1.0.164, hermes-agent-0.11.0, omo-5.1.22,
  dsh-tui-0.1.6-alpha.2, nixos-version.
- `nix-store -qR --include-outputs $(nix path-info --derivation .#dsh)` = 818 outputs, 4.18 GiB
  (cache-resolvable), ZERO overlap with the 822-path runtime set => additive ~4.18 GiB.
- same for .#omo = 329 outputs / 1.25 GiB, 0.54 GiB shared => additive ~0.72 GiB.
- Per-package closure (GiB, all inside the runtime set): playwright-browsers 2.14
  (narSize 1400 B — it is a symlink wrapper; closureSize 2,300,237,320 B; closureDownloadSize
  823,349,326 B), docker-28.5.2 0.90, rustc-wrapper 1.53, cargo 1.58, devenv 0.86,
  opencode 0.50, gcc-wrapper 0.34, git 0.33, go 0.22, python3 0.17, bun 0.13, cmake 0.13,
  docker-compose 0.10.
- Local declarative image /nix/store/nj0ns...-machine0-image/...qcow2.gz = 4,085,648,627 B
  (3.81 GiB); qcow2 header virtual size 0x4_6160_0000 = 18,813,550,592 B = 17.52 GiB.
- `nix build --dry-run .#coding` lists **373 derivations to build** (mostly
  pnpm-workspace-* / dsh-*). Sampled dsh output paths are NOT on
  deepseek-harness-nix.cachix.org nor cache.nixos.org ("path is not valid") — so the dsh
  binary cache does not currently cover this preset. claude-code also absent from
  cache.nixos.org (unfree => not on Hydra). cache.garnix.io DNS did not resolve here.
- omo drv is omo-5.1.22 (working tree already bumped past README's 5.0.0-0.beta.82;
  machine0 git tree has uncommitted changes).

## Mechanism facts
- image = make-disk-image.nix with format "qcow2" (NOT "qcow2-compressed") + postVM gzip.
  `-c` is only added when format=="qcow2-compressed".
- virtualisation.diskSize default = "auto" (diskSizeAutoSupported true) => disk = closure + 512M.
- boot.growPartition=true + fileSystems."/".autoResize=true => Min Disk = source/builder VM disk.
- nix.optimise.automatic=true => services.nix-optimise runs `nix-store --optimise` at
  nix.optimise.dates (default 03:45 + random delay). `nix.settings.auto-optimise-store` NOT set.
- nix.gc.automatic weekly, `--delete-older-than 14d`.
- machine0 CLI bundle: image table shows Size=`sizeGb` GB, Min. Disk=`minDiskGb` GB
  (/home/mei/.local/lib/node_modules/@machine0/cli/dist/cli.bundle.mjs, fns Tk/Rk).
- CLI 1.0.164 present but NOT logged in => could not run `machine0 images get m0-coding`.

## Deliverable sent to lead: full A4 report (a)-(d) + EXPAND + CLAIMS via task_send.

## Learnings
- `nix path-info -S <invalid path>` prints a confusing prerequisite listing then errors;
  use `--store https://<cache>` to size paths the local store lacks.
- `nix-store -qR --include-outputs <toplevel.drv>` gives the BUILD closure, not the system
  runtime closure (only 21/189 syspkgs present) — use the syspkgs' own `-r` closures instead.
