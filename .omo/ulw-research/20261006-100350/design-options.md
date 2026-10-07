# Design options (lead draft, in progress — not the synthesis)

Requirements: R1 no second USB · R2 login password after install · R3 reuse the sops material on
this laptop · R4 minimal manual steps on flake ISO or official ISO · R5 custom-installer verdict.

## Settled facts (evidence in observation-manifest / wave files)

- F1 `--extra-files` = `tar -cpf- . | ssh 'tar -C /mnt -xf- --no-same-owner'`; destination /mnt;
  root:root; modes preserved; `--chown` after. (lane3 source L876-885; lane8 docs; upstream test.)
- F2 nixos-anywhere has no local mode (`--target-host` mandatory unless `--vm-test`); SSH-to-self is
  the local path; upstream points local installs at disko-install. (lane3 L442-444, issue #455.)
- F3 Flake ISO today: `hardware-enroll` oneshot, `VARIANT_ID=installer`, tmpfs root, sshd running,
  root+mei accept the fleet key. (lead eval; lane5.)
- F4 Pinned kernel has `CONFIG_BTRFS_FS=m` (lead probe: linux-config-7.2.7); the ISO image does NOT
  ship `btrfs-progs`; the modulesTree realization for the ISO is not in the store yet. (lead probes.)
- F5 A `path:` flake build includes untracked files; a `git+file:` flake does not (lead probe) —
  `nix build path:.#iso.<host>` can bake local secrets into an ISO; plain `.#iso.<host>` cannot.
- F6 Bootstrap contract: `/var/lib/nixos-bootstrap/<user>-password.hash`, yescrypt `$y$`, single
  newline, salt<=86, dir 0700/file 0600, consumed to `!` after the users activation. (lane1.)
- F7 On this laptop: age key = &workstation (age12kpavl...), `secrets/github-ssh.yaml` decrypts,
  `remembrance-keys.yaml` absent. (lead probes O2/O3/O8.)
- F8 `--copy-host-keys` is flaky (#598/#604) — prefer `--extra-files`. (lane8.)
- F9 disko-install `--extra-files SOURCE DEST` copies after partitioning; open bug #1046: it
  continues after a failing disko script. (lane8.)
- F10 This laptop's old root: nvme0n1p2 btrfs with subvolumes /@ and /@home (and @root,@srv,@cache,
  @log,@tmp); fstab gives UUID 5e4589ab-31d9-4ad5-be15-13ec6a4fc5f6. (lead probes.)
- F11 The app flow today: detect host -> probe -> work tree -> fold or `--skip-fold --save` ->
  `host-install.sh --install-only` -> `nixos-anywhere` to root@127.0.0.1. (repo commit 6992dd2.)

## Mechanisms

### M1 — password (closes R2)
Generate a random password in the installer, stage the yescrypt hash to
`/var/lib/nixos-bootstrap/mei-password.hash` (0700 dir / 0600 file, root:root) via
`--extra-files`, print the password once to the console (`password: <...>` + a warning not to share).
Evidence: F1 (modes/ownership), F6 (format/consumer). Open: password-proof's executed validator
proof; the `--no-root-passwd` question only concerns root, not mei.

**M1b — this is a RESTORE, not an invention (lane2).** The repo shipped exactly this mechanism until
2026-08-19: `bin/nixos-anywhere-bootstrap-password.sh` (final @ f7015a56) required tmpfs
`XDG_RUNTIME_DIR`, staged `var/lib/nixos-bootstrap` (0700) with a `mkpasswd --method=yescrypt` hash
(0600), validated LF/single-line/`$y$...`-86-char-salt via regex, then ran
`nixos-anywhere --extra-files "$stage" --chown var/lib/nixos-bootstrap 0:0 --build-on local
--no-substitute-on-destination`. The scripts vanished in the d4f2559 consolidation without a reasoned
removal commit; a prior ulw-research run (20260711-124332) designed it and two gate reviews rejected
then one approved it. Legacy failure modes to re-check: the validator's symlink hole flagged in
`.omo/evidence/default-nixos-password-gate-review.md` (it tested `-e` before `-L`).
Implementation should port that script into the app/ISO flow (or restore it as a component) and
re-add its tests (bootstrap-password-mutations.sh + install-helper.sh were deleted too).

### M2 — artifacts without a USB (closes R1)
Stage the enrollment artifacts (candidate, intake document, host key) into the installed system,
e.g. `/var/lib/nixos-enrollment/` (0700 root) via the same `--extra-files`. After first boot the
operator retrieves and commits them. No external media. `--save` stays as an option, not a
requirement. Evidence: F1, F2.

### M3 — sops material (closes R3)
Three routes, ranked:
1. **Read from the old disk during install** (flake ISO only in practice): mount
   `nvme0n1p2` with `-o ro,subvol=/@home`, copy `~/.config/sops/age/keys.txt` (and any
   `secrets/*.yaml` present) into the target, then stage them like M2. Needs btrfs module (F4) and
   the known subvolume names (F10).
2. **Bake into the ISO** via `nix build path:.#iso.antagony` with an untracked
   `iso-secrets/` (F5). No old-disk dependency; the ISO then carries secrets on the stick.
3. **Do nothing**: `secrets/github-ssh.yaml` is tracked and travels with the flake; the age identity
   is what the new host lacks. sops-nix's clean BYO path is `sops.age.keyFile` + empty sshKeyPaths
   (lane8) — a repo change to `modules/aspects/features/sops.nix` if route 3 is chosen.
Verdict: route 1 is the best fit for "boot the ISO once, nothing else"; route 2 is the fallback for
a machine with no recoverable disk state.

### M4 — autostart (closes R4)
Chain the existing ISO `hardware-enroll` oneshot into an install oneshot behind an explicit gate.
Candidate gates: kernel cmdline (`nixos.autoinstall=1`), a boot-menu entry, or both. The gate is the
"explicit same-invocation yes" the repo's anti-patterns require; console output + `OnFailure` to a
rescue target keep it debuggable. Patterns to compare: tfc oneshot, misuzu getty hijack, discourse
39748 boot-menu target, fricklerhandwerk login-hook. (iso-autorun member's design pending.)
Note: the ISO must NOT autostart the install on every boot of the ISO (any boot of the stick on any
machine would wipe it) — the gate is mandatory, not optional.

### M5 — official ISO (R4 second half)
No custom oneshot is possible; the app's one command remains, with the same M1/M2 staging applied by
the app itself (it already installs via nixos-anywhere). `live.nixos.passwd=` only sets the
installer's root password and is not needed (the app installs its own root key).

### M6 — custom installer verdict (R5)
The flake ISO already IS a custom installer. "Custom" only adds value if it must: (a) carry baked
secrets (route 2), (b) boot straight into installation (M4), or (c) work air-gapped (closure baking,
lane5). It costs: a grub.cfg patch (brittle, discourse 39748) or a gate + oneshot, plus test
coverage (currently ZERO — lane1). The password half needs no new installer at all: the mechanism
already existed in-tree (M1b) and only needs restoring into the existing app/ISO flow. Recommendation
draft: no new installer project; extend the existing flake ISO with M1b+M2+M4 and keep
`path:`-built ISOs for secret baking.

## Open questions

- Q1 btrfs mount from the ISO kernel (skeptic running; config says `=m`, so almost certainly yes).
- Q2 whether the enrollment fold matters at all (contrarian pending).
- Q3 the exact gate + unit ordering for M4 (iso-autorun pending).
- Q4 where the printed password lands if the console scrolls (journal? tty1 file?).
