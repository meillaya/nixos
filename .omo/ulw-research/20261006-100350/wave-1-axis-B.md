# Wave 1 — member anywhere-flags (Axis B: tool surface) — completed

Pins: nixos-anywhere HEAD 3c6e0cc24fbc69b97a22cf09bb6ca361354e0490 (one release ahead of tag 1.13.0,
not in flake.lock); disko flake.lock rev ff8702b4de27f72b4c78573dfb89ec74e36abdf1;
nixpkgs flake.lock rev 4975466d324710c576dc11ad614684e6bd8cad8e (nixos-install now lives at
pkgs/by-name/ni/nixos-install/, not the old installer/tools path).

## Decisive per-flag facts (nixos-anywhere @ pin)

- `--extra-files`: `tar -C <dir> -cpf- . | ssh 'tar -C /mnt -xf- --no-same-owner'` then
  `chmod 755 /mnt`; runs INSIDE the install phase BEFORE `nixos-install` (L877 vs L916) — hence
  staging a password hash there works; modes preserved; ownership root.
- `--chown <path> <own>`: `chown -R` AFTER the copy; repeatable; DO NOT chown
  `/var/lib/nixos-bootstrap` (the repo requires dir 0700/file 0600 root:root).
- `--disk-encryption-keys`: lands in the INSTALLER environment (not /mnt) and ONLY when the disko
  phase runs; silent no-op otherwise.
- `--phases`: kexec,disko,install,reboot; `--stop-after-disko`/`--no-reboot` are deprecated aliases.
- `--generate-hardware-config`: runs the backend ON THE REMOTE and writes a local file.
- `-s, --store-paths`: offline path (prebuilt disko script + toplevel), still needs a target host.
- No local mode: `--target-host` mandatory unless `--vm-test` (L442-443); issue #455 closed with
  "use disko-install".

## nixos-install (nixpkgs pin)

- Both `--no-root-password` and `--no-root-passwd` hit the same case branch (L92-93) — lane7's
  "rename" is resolved: both work.
- It NEVER sets a user password; it only prompts for ROOT, and only when stdin is a tty and the
  target has `passwd` (L330). User login comes from the config via activation
  (`nixos-enter ... switch-to-configuration boot`, L322).

## disko-install (disko pin)

- Fully local, root-only, NO SSH, NO kexec: builds installToplevel + closureInfo + disko script,
  runs `DISKO_SKIP_SWAP=1 <disko_script>`, then `cp -ar <source> <mountPoint>/<destination>` for
  `--extra-files SOURCE DEST`, then
  `nixos-install --no-channel-copy --no-root-password --system <t> --root <mountPoint>`.
- Offline support: if the target DB is absent it `xcp`s store paths and `nix-store --load-db`.
- Traps: parent dirs of --extra-files are created with `mkdir -p` under the ambient umask (0755) —
  the repo's 0700 dir requirement needs a workaround; no `--chown` (pre-own the source);
  open bug #1046: disko-install CONTINUES after a failing disko script.

## Verdicts (member's, evidenced)

- (a) password hash staging: nixos-anywhere YES (exact modes); disko-install PARTIAL (dir mode trap);
  nixos-install YES if you place it yourself.
- (b) enrollment artifacts: nixos-anywhere YES (dest = target /, --chown available);
  disko-install YES with ownership caveat.
- (c) fully local without SSH: nixos-anywhere NO; **disko-install YES**; nixos-install YES after
  partitioning+mounting.

## Contradictions found (code wins)

1. docs/howtos/extra-files.md says "after installation"; code copies before nixos-install.
2. lane7's flag "rename" is not a rename — both spellings are aliases.
3. --disk-encryption-keys is also gated on the disko phase, not just "before installation".

## Leads

- L22: disko `--mode mount` repair path (preserve-and-repair instead of wipe) — relevant to reading
  the old disk / preserving the on-disk sops material (owner: lead + iso-autorun).
- L23: offline `--store-paths` closure baking — not needed on the ThinkPad (network available).
- L24: disko #1046 continue-on-failure → affects any disko-install-based design (documented risk).
