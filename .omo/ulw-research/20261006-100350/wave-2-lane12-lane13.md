# Wave 2 — lane12 (ISO design) + lane13 (skeptic) — completed

## lane12 — the minimal-diff ISO autostart design (adopted, with two lead amendments)

Adopted elements:
- Unit `nixos-autoinstall.service`: `wantedBy = ["multi-user.target"]`, `wants/after
  network-online.target`, `after sshd.service` + `hardware-enroll.service` (soft, not Requires),
  `Type = "oneshot"`, `RemainAfterExit = true`, `SuccessAction = "reboot"`,
  `OnFailure = "iso-install-rescue.target"`, `StandardOutput/Error = "journal+console"`,
  `unitConfig.ConditionKernelCommandLine = "nixos.autoinstall=1"`.
- The Unit-level `ConditionKernelCommandLine` prevents the unit from even activating unless the
  operator appended the flag at the GRUB menu — no auto-wipe on a plain boot; no grub.cfg patching.
- The service body runs the existing one command against a baked `${inputs.self}`
  (`nix run path:$NIXOS_FLAKE#install -- --yes`).
- Staging lives in the app (password + enrollment artifacts), so the official ISO gets the same
  password/artifact fix for free; `bin/host-install.sh` learns to forward `--extra-files DIR`.
- Do NOT pass `--chown var/lib/nixos-bootstrap` (root extraction already yields 0:0; the historical
  script's chown was belt-and-braces).
- Test plan: extend `tests/dendritic-config-eval.nix` with an ISO eval wall
  (`ConditionKernelCommandLine`, `SuccessAction`, `OnFailure`, `network-online` deps,
  `boot.supportedFilesystems.btrfs`, and the NEGATIVE assertion that `nixos.autoinstall=1` is not in
  `boot.kernelParams`), add a grep check for the staging invariants, re-add the deleted password
  mutation tests, and add the repo's first ISO VM test (plain boot = inert; gated boot = install).

Two lead amendments:
1. Add `boot.kernelModules = [ "btrfs" ]` alongside `boot.supportedFilesystems = [ "btrfs" "vfat" ]`.
   Lead eval: `kmod` IS in both ISOs' systemPackages (modprobe present) and `boot.kernelModules` is
   the supported stage-2 load lever; this closes the skeptic's "module presence != loaded" gap.
2. The gate is a TRIGGER, never an AUTHORIZATION (skeptic's rule): the autoinstall path must also
   require the DMI/disk match against the enrolled record, and write a persistent completion marker
   (e.g. on the ESP) before disko, checking it first so a reboot cannot re-run a finished/partial
   install. (The existing app already probes the hardware; the match check is a small addition.)

Also confirmed pre-existing defect: `iso-images.nix:44` writes `/etc/hardware-enrollment/<host>.json`
but no code creates that directory (grep: only the write and the read), so the ISO's `hardware-enroll`
oneshot fails before `auto_enroll` — masked by `|| true`. One-line fix: `mkdir -p` in the script.

## lane13 — skeptic verdicts (adopted)

| claim | verdict | note |
|---|---|---|
| C7 extra-files modes | STANDS (scope-limited) | root extraction keeps same-permissions; `--no-same-owner` is ownership-only; the 0700-dir/setuid extensions rest on VA1 (lead experiment), not the upstream test |
| C8 btrfs on the ISO | WEAK -> fixed | "btrfs-progs present" refuted for iso.antagony (verified); module presence != loaded; remedy = supportedFilesystems + kernelModules (lead eval: kmod present) |
| silent wipe | STANDS | disko pin correction: cite ff8702b4 (flake.lock), not 725ea35 |
| C2 password | STANDS (contract) / WEAK (staging leg) | mutableUsers sentinel safety verified from update-users-groups.pl; the staging leg has an executed validator proof (VA4) but no install->reboot->login e2e |
| independence audit | - | C7 and C2 are single-source clusters with several readers; only the silent-wipe claim has three foreign sources |

Skeptic's new leads:
- L30: does `nixos-install` run the target's activationScripts (validator at install time vs first
  boot)? Residual.
- L31: the trigger-vs-authorization rule + persistent completion marker (adopted into the design).
