# ISO autostart + staging design (lead-authored; lane12 pending — supersede if it lands)

Goal: booting the flake ISO and typing nothing (or nothing beyond selecting the entry) installs
`antagony` with a password, carrying the enrollment artifacts into the installed system.

## D1. ISO config additions (modules/flake/iso-images.nix, in the existing `extendModules`)

1. `boot.supportedFilesystems = [ "btrfs" "vfat" ]` — verified absent on `iso.antagony` today
   (`supportedFilesystems = {iso9660,overlay,squashfs,tmpfs}`, `btrfsProgs = false`; remembrance's ISO
   has both). Brings `btrfs-progs` via `system.fsPackages`, enables reading the old disk before wipe.
2. Bake the app + flake source into the image (`environment.etc."nixos-install/flake".source = self;`
   or copy `apps/` + `modules/` + `scripts/` into the store), so the run needs no GitHub fetch
   (lane10 G6). Chain that: the app is fetched today, which breaks a no-network install.
3. New unit `auto-install`:
   - `wantedBy = [ "multi-user.target" ]` (enabled) but
     `unitConfig.ConditionKernelCommandLine = "nixos.autoinstall=1"` — the unit only runs when the
     operator adds the flag at the boot menu (GRUB `e`, append) or boots a dedicated entry. No
     grub.cfg patching (brittle per discourse 39748).
   - `after = [ "network-online.target" ]; wants = [ "network-online.target" ]`; `Type = "oneshot"`;
     `RemainAfterExit = true`; stdout to journal+console so the password print and progress are on
     tty1; `unitConfig.OnFailure = [ "rescue.target" ]` so a failure drops to a shell instead of a
     half-partitioned reboot loop.
   - `SuccessAction`/`reboot`: the app's install phase ends with nixos-anywhere's reboot; the unit
     must not re-run on the next boot of the *installed* system — the gate flag lives in the ISO's
     boot entry, not in the installed system, and the ISO ramdisk is gone after the wipe. Add
     `ConditionPathExists=!/run/autoinstall-done` + a touch on success as belt-and-braces against a
     re-run within the same boot.
4. The service body (shell):
   - generate the password non-interactively: `pw=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)`,
     hash via `mkpasswd --method=yescrypt --stdin <<<"$pw"` (INTERACTIVE by default — must pass
     `--stdin`), validate against the module's regex, `chmod 600`, dir 0700;
   - build the staging tree: `var/lib/nixos-bootstrap/mei-password.hash` +
     `var/lib/nixos-enrollment/{<host>.json,<host>.intake.json,<host>.host-key}` (0700/0600);
   - print `install: password for mei: <pw>` once, then `unset pw`;
   - run the app non-interactively: `<flakedir>/apps/x86_64-linux/install --yes` with the staging
     dir handed to it (new `--stage` flag), which passes
     `--extra-files "$stage" --chown var/lib/nixos-bootstrap 0:0 --chown var/lib/nixos-enrollment 0:0`
     to nixos-anywhere (historical shape, wave-1-lane2.md).
   - The app's live-root guard passes (ISO root is tmpfs, verified).

## D2. App/orchestrator changes (shared by both ISOs)

- `apps/x86_64-linux/install`: add the staging step (D1.4 items 1-2) and pass `--extra-files` down;
  keep `--yes`, the live-root guard, and the enrollment checkpoint; `--skip-fold --save` stops being
  required on ThinkPads (the host key now persists inside the installed system).
- `bin/host-install.sh`: accept `--extra-files DIR` (or reuse an env var) for the operator path; keep
  the fold for machines that DO have the sops store.
- Password staging satisfies the module contract exactly: yescrypt `$y$`, one LF line, salt <=86,
  0:0, dir 0700, file 0600 (lane4/lane11/lifecycle test).
- `hashedPasswordFile` WINS over every competing option on the pinned nixpkgs (override-order VM
  test), so no collision handling is needed for mei; root/nixos collisions are official-ISO-only.

## D3. Safety

- Nothing installs without the explicit gate (ConditionKernelCommandLine) — a plain boot of the stick
  is inert. The gate is the same-invocation confirmation the repo's anti-patterns require.
- The live-root check stays; the app re-checks `--yes` in the destructive stage.
- nixos-anywhere's disko path wipes WITHOUT its own prompt (`_legacyDestroy`), so the gate + guard are
  the only protections — document that in the ISO banner text.
- `OnFailure=rescue.target` prevents the worst failure mode (half-partitioned machine rebooting into
  the installer again): with the gate flag, a re-run would be an operator choice, not a loop.

## D4. Official NixOS ISO residue (honest statement)

No custom unit can be added; the ISO is upstream's. The best achievable: one command
(`nix run github:meillaya/nixos#install -- --yes`, flakes flag included), with the SAME staging
(password + artifacts) so the result is identical. Everything else requires the flake ISO (or
`path:`-built variants for baked secrets).

## D5. Tests to add (G4)

- Extend `modules/flake/checks.nix` with the (currently unwired) `tests/bootstrap-password-*` runs.
- A NixOS VM test that builds the ISO config, boots it with `nixos.autoinstall=0` (assert: nothing
  happens) and with `=1` (assert: the unit runs, stages the hash, and the validator accepts it).
- Re-add the deleted `tests/bootstrap-password-mutations.sh` (consumer: the orphaned
  `tests/bootstrap-password-config-eval.nix`).
