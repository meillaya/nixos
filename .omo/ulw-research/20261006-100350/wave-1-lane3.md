# Wave 1 — lane3 (nixos-anywhere source dive, pinned 3c6e0cc24fbc69b97a22cf09bb6ca361354e0490)

Sources: src/nixos-anywhere.sh, src/get-facts.sh, tests/from-nixos.nix, docs/howtos/extra-files.md,
docs/howtos/no-os.md, docs/reference.md. Latest tag 1.13.0 (2025-11-13) predates `--force-kexec`.

## Decisive facts (quoted at the pinned SHA)

- `--extra-files` = `tar -C "$extraFiles" -cpf- . | ssh 'tar -C /mnt -xf- --no-same-owner'`, then
  `chmod 755 /mnt` (nixos-anywhere.sh L876-L881). Destination root = `/mnt`; ownership forced to the
  extracting user (root) via `--no-same-owner`; **modes preserved** (root extraction keeps
  same-permissions by default). Upstream integration test asserts a source `chmod 600` file is `600`
  on the target after reboot, and that `/var/lib/secrets/key` survives first boot
  (tests/from-nixos.nix L30-31, L46, L61, L65-66).
- `--chown <path> <ownership>`: `chown -R` applied after the copy (L883-885).
- kexec gate: `get-facts.sh` L11 checks `/etc/os-release` for `VARIANT_ID="?installer"?`; `runKexec`
  returns early when installer and `--force-kexec` is not set (L700-703). `--force-kexec` exists only
  on `main` (unreleased); 1.13.0 always skips kexec for installers.
- Phases: `kexec,disko,install,reboot` (L27-31); `--phases` comma list; unknown names abort.
- **No local install**: `--target-host` is mandatory unless `--vm-test` (L442-444); issue #455
  ("Installation on a local machine") closed with "use disko-install". Local installs therefore run
  through SSH-to-self (root@127.0.0.1) - exactly what the repo's app does.
- `nixos-install --no-root-passwd --no-channel-copy --system <toplevel>` is ALWAYS used (L916):
  nixos-anywhere never sets a root password; user passwords come from the config.
- `--disk-encryption-keys` uploads into the installer env (umask 077), only when the disko phase runs.

## Leads raised

- L10: does a config-specified root hash still land despite `--no-root-passwd`?
- L11: does `--extra-files` restore setuid/setgid/sticky bits and special files? (security review)
