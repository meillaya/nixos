# ULW-Research Synthesis: zero-touch NixOS install for the ThinkPad (antagony)

Members + lanes: 8 members (6 axes + 2 attack) + 14 lanes · Waves: 2 · Excursions: 3 ·
Sources: 28 numbered (46 ledger rows) · Debate rounds: 6 logged rounds / 10 attack verdicts
(skeptic lane13, contrarian lane14) · Elapsed: MEASURED 24 min (outcome finish elapsedMinutes)

## Executive summary (evidence: [S1][S20][S25])

The user asked for: no second USB, a login password written automatically, reuse of the sops
material, minimal manual steps on both ISOs, and a verdict on "maybe we need a custom installer".

1. **The hard requirement is the password, and the fix is a RESTORE (10-40 lines).** This repo
   shipped the mechanism until 2026-08-19: a SHA-pinned `mkpasswd --method=yescrypt` per-install
   password staged via `nixos-anywhere --extra-files` into `/var/lib/nixos-bootstrap/mei-password.hash`
   (0700 dir / 0600 root file) and consumed by the existing activation contract. It was lost in the
   `d4f2559` merge; the later target-side rewrite kept everything except the caller. The validator
   contract still exists (symlink checks fixed, yescrypt enforced, sentinel consumption tested);
   `hashedPasswordFile` is the highest-precedence password option on the pinned nixpkgs, so a staged
   file overrides any alternative (initialPassword literals are silently overridden, do not use
   them). Executed proof (VA4): a generated yescrypt hash staged per the contract passes the repo's
   real validator (`rc=0`, silent), while mode-644 and sha512 variants fail with the contract's
   messages.
2. **"Reuse the sops store" is not a requirement as stated, but one identity is load-bearing and
   irreversible.** Nothing in `modules/**` declares `sops.secrets` (lane14/lane25 greps); executed
   runs show `gen_trust --host antagony` succeeds with no store (fleet fallback) while `--host
   remembrance` fails closed without it; the fold only escrows a host key nothing consumes. What DOES
   matter: the `&workstation` age identity at `~/.config/sops/age/keys.txt` is the only held recipient
   that unwraps `secrets/github-ssh.yaml`, it lives on the disk being wiped, and the
   fleet/install-authorizer private key is not present on this laptop (executed grep). Carry the
   identity into the installed root (same `--extra-files` staging) or it is destroyed. Reusing
   `remembrance-keys.yaml` is impossible here anyway (its rule encrypts to `&admin`+`&recovery`, not
   held). [S20][S25]
3. **No second USB is solved by the same staging step**: put the enrollment artifacts, the age
   identity, and (optionally) the GitHub key into the installed system's persistent `/var/lib/...`
   root; `--save` stops being a requirement (the ISO's work tree is only RAM). [S20][S21]
4. **Autostart is the user-requested extra; it must be a trigger, never an authorization.** The flake
   ISO can chain the existing `hardware-enroll` oneshot into a gated install unit
   (`ConditionKernelCommandLine = "nixos.autoinstall=1"`, `SuccessAction = reboot`, `OnFailure` to a
   rescue target, console output). A plain boot of the stick must stay inert. The autostart path
   additionally requires a DMI/disk match against the enrolled record and a persistent completion
   marker so a reboot cannot re-run a finished or partial install (nixos-anywhere's disko path wipes
   with no confirmation of its own). The official NixOS ISO cannot autostart (no custom units); there
   the one command remains, and it inherits the same password/identity staging because that lives in
   the app. [S22][S23]
5. **Verdict: no new installer project.** The flake ISO already is a custom installer; the marginal
   capability is autostart, which is about one module plus test coverage. A new project buys nothing
   the user asked for, and its known shapes (grub.cfg patching) are brittle. [S10][S20][S22]

## Findings by theme

### 1. Password: restore the caller, keep the contract
- Contract: `hashedPasswordFile = /var/lib/nixos-bootstrap/mei-password.hash`; validator before
  `users`, consumer rewrites to `!` after; `$y$`, one LF line, salt <=86, 0:0, 700/600, no symlinks
  [S3]; the old gate-review symlink hole is closed (`! -L` before `-e`) [S18].
- Precedence on the pinned nixpkgs: `hashedPasswordFile` wins (rightmost in `overrideOrderMutable`;
  nixpkgs' own VM test calls the old warning order "in fact wrong") [S12][S19].
- Generator must be non-interactive (`mkpasswd` prompts by default; use `--stdin`) [S19].
- Historical caller (recovered verbatim): tmpfs stage, regex validation, `--extra-files`,
  `--build-on local`, `--no-substitute-on-destination`, stdin passthrough [S1].
- Executed: VA4; staging modes VA1; downstream acceptance of `$y$` by libxcrypt/shadow/PAM [S4].

### 2. Identity and artifacts: what must leave the disk before it is wiped
- `&workstation` age identity + the `&github` SSH key (derived: `~/.ssh/id_ed25519` is the GitHub
  key) + (if present) any `secrets/*.yaml` to stage into the installed root [S20][S25]; `path:`-built
  ISOs can alternatively bake untracked material, at the cost of world-readable copies in /nix/store
  [S15][S25].
- Old-disk route verified [S25]: `btrfs.ko` ships in the kernel modules output, subvolume `@home`
  mounts read-only from an ISO, and the identity lives there; btrfs-progs is absent but a
  single-device `mount -o subvol=@home,ro` needs no userspace helper [S24][S25].
- Enrollment artifacts (candidate, intake document, host key) ride the same staging [S21]; `--save`
  becomes optional [S20].
- The fold remains for machines that hold a writable store; on this laptop it is skipped, and nothing
  at runtime consumes the folded key [S20][S21].

### 3. Autostart on the flake ISO (gated)
- Unit shape, ordering and gate per lane12 [S22]: `Wants/After network-online.target`,
  `After sshd.service hardware-enroll.service`, `Type=oneshot`, `RemainAfterExit`,
  `ConditionKernelCommandLine`, `SuccessAction=reboot`, `OnFailure` to a rescue target, journal+console.
- Safety additions (skeptic) [S23]: the flag is a trigger, never authorization; require a host/disk
  match and a persistent completion marker; no auto-reboot loop.
- The ISO must also gain `boot.supportedFilesystems = [ "btrfs" "vfat" ]` (btrfs-progs) and
  `boot.kernelModules = [ "btrfs" ]` (stage-2 load) so it can read the old disk first; `kmod` is
  already in the ISO's systemPackages (lead eval) [S6][S23][S24].
- Pre-existing defect found: `iso-images.nix` writes `/etc/hardware-enrollment/<host>.json` without
  creating the directory, so the ISO's `hardware-enroll` oneshot fails silently under `|| true`
  [S24]. One-line fix (`mkdir -p`).

### 4. Official NixOS ISO: honest residue
One command remains; the same app-side staging gives the same password/identity result; the flakes
flag is required. No custom unit can be added [S22]. The official ISO's `initialHashedPassword`
collision affects root/nixos only, not mei, and the flake ISO does not import that profile [S19].

### 5. Engine choice
Keep the app's SSH-to-self nixos-anywhere path (no local mode exists upstream; SSH-to-self is what the
app already does; `--extra-files` lands before activation with modes preserved) [S5][S22].
disko-install is the only native-local alternative but has a 0755 parent-dir trap, no `--chown`, and
continues after a failed disko script (#1046) [S17].

## Codebase findings (absolute paths, sources [S11][S21])

- `apps/x86_64-linux/install`: entry point; no password/identity staging today; `--skip-fold --save`
  is a workaround for the RAM work tree; live-root guard + `--yes` are the only gates.
- `bin/host-install.sh`: `--install-only` path has no `--extra-files`; must forward a staging dir.
- `modules/nixos/bootstrap-password.nix`: the contract to satisfy (validator before `users`,
  consumer after, `! -L` before `-e`, `hashedPasswordFile` path).
- `modules/flake/iso-images.nix`: `hardware-enroll` oneshot (missing `mkdir -p` defect), installer
  marker, ISO built from the host config via `images.iso`.
- `modules/aspects/features/sops.nix`: `sops.age.sshKeyPaths = ~/.ssh/id_ed25519` (the identity the
  new host needs).
- `.sops.yaml`: `remembrance-keys.yaml` rule encrypts to `&admin`+`&recovery` only.

## Sources (ranked)

S1 recovered `bin/nixos-anywhere-bootstrap-password.sh` @ f7015a56 (lane2 via GitHub API; deleted in d4f2559).
S2 prior research + gate reviews @ d4f2559 (lane2 recovery).
S3 `modules/nixos/bootstrap-password.nix` + `tests/bootstrap-password-lifecycle.sh`.
S4 nixpkgs rl-2211 + libxcrypt/shadow/PAM (lane4) + VA4.
S5 nixos-anywhere src L876-885 + tests/from-nixos.nix @ 3c6e0cc (lane3/lane9/anywhere-flags).
S6 lead nix evals: iso.antagony vs iso.remembrance (btrfs gap), kernel config (`CONFIG_BTRFS_FS=m`), kmod present.
S7 sops-nix module + sops-install-secrets @ dcd241b (lane4).
S8 discourse 39748 (grub patching brittle).
S9 repo tests + checks.nix (lane1): ISO autostart zero coverage.
S10 discourse 33244/50618/51068/47022 + tfc + misuzu + Bossearch (lane7/prior-art).
S11 repo commits 6992dd2/731de47 and the app source.
S12 nixpkgs users-groups.nix `overrideOrderMutable` + update-users-groups.pl.
S13 disko `_legacyDestroy` (no confirmation) @ ff8702b4 (lane9 pin corrected by lane13).
S14 lead probes: age-keygen -y, sops -d, find sweeps; .sops.yaml rules (lane6).
S15 lead probes: `path:` vs `git+file` flake inclusion.
S16 /proc/mounts + fstab; CachyOS subvolume layout (lane6).
S17 disko-install source + #1046 + nixos-anywhere #455 (lane8/anywhere-flags/lane9).
S18 lane11: the symlink hole is closed at HEAD (`! -L` before `-e`).
S19 lane11: nixpkgs `password-option-override-ordering.nix` (rightmost wins; mkpasswd interactive).
S20 lane14: nothing consumes the store; the `&workstation` identity is the irreversible item.
S21 lane10: the gap map (G1-G7) and the port-vs-reinvent verdicts.
S22 lane12: the ISO unit/gate design + official-ISO residue + test plan.
S23 lane13: skeptic verdicts; trigger-not-authorization rule; pin corrections; independence audit.
S24 lead greps/evals: `/etc/hardware-enrollment` has no creator (defect); kmod present.
S25 secrets-route executed report: identity inventory, gen_trust runs (antagony OK / remembrance
   fails), old-disk mount proof (btrfs.ko present), path: vs git inclusion + world-readable leak
   surface, fleet/install-authorizer private key absent.

## Verified claims (method: [S1][S3][S5][S19][S24])

- VA1 (executed, lead): tar staging with `--no-same-owner` preserves 0600 files and 0700 dirs exactly
  under umask 022/077; setuid is dropped for non-root extraction only.
- VA2 (executed, lead): pinned kernel `CONFIG_BTRFS_FS=m`; `iso.antagony` lacks btrfs/vfat support and
  btrfs-progs; `iso.remembrance` has both; `kmod` present on both ISOs.
- VA3 (executed, lead): `path:` flakes include untracked files; `git+file` does not.
- VA4 (executed, lead): generated yescrypt hash + LF + 0700/0600 + unlocked shadow, validator `rc=0`
  silent; 0644 gives rc=1 "expected numeric owner 0:0 mode 0600"; sha512 gives rc=1 "expected
  yescrypt hash".
- VA5 (source-verified): password precedence; `!` sentinel safe under mutableUsers.
- VA6 (source-verified, lane3 + upstream test): `--extra-files` runs before nixos-install; modes
  preserved; owner root.
- VA7 (source-verified, lane9/lane13): nixos-anywhere's disko path wipes without confirmation.
- VA8 (executed, secrets-route): `gen_trust --host antagony` exit 0 without a store;
  `--host remembrance` exit 1; `mount -o subvol=@home,ro` works from an ISO; the fleet key is absent.

## Epistemic instrumentation (summary, sources [S2][S23])

Intent-diff closed: I1 (staging solves no-USB), I2 (restore solves password), I3 (reframed to
identity preservation), I4 (gated autostart on the flake ISO; honest official-ISO residue),
I5 (gates preserved: `--yes` + live-root + trigger-not-authorization), I6 (no new installer).
Claim graph: 11 nodes (wave-2 findings are folded into the wave files and this synthesis); the
high-risk nodes carry at least two independent sources or an executed verification; the independence
audit is recorded (C7/C2 are single-source clusters; the silent-wipe claim has three foreign
sources). Observation manifest: 11 rows plus the wave-file observations. Verification economics: all
contested mechanisms either executed (VA1-VA4, VA8) or source-pinned; the one unexecuted item is a
real ISO boot with the gate.

## Debate record (sources [S20][S23])

- Skeptic (lane13): 5 verdicts. C7 STANDS (scope-limited to root extraction), C8 WEAK (btrfs-progs
  false, module-load unverified), silent-wipe STANDS (pin corrected to ff8702b4), C2 STANDS for the
  contract / WEAK for the staging leg, plus an independence audit that demoted two "multi-source"
  claims to single-source clusters.
- Contrarian (lane14): 5 premise attacks. Custom-installer is a category error; store-reuse is not a
  requirement (identity preservation is); the password caller is the only missing piece; `--save` is
  redundant once staging lands in the target; R2 is the load-bearing requirement.
- Both attacks changed this synthesis: the identity-preservation addition, the
  trigger-not-authorization rule, the ISO additions (kernelModules + supportedFilesystems), and the
  downgrade of "reuse the store" from requirement to reframed risk.

## Contradictions and their resolution (sources [S5][S23])

1. extra-files "after installation" (docs) vs before nixos-install (code), code wins (three readers).
2. `--no-root-passwd` vs `--no-root-password`, both accepted aliases; not a rename.
3. Password precedence: old warning wording vs source; source wins, hashedPasswordFile is rightmost.
4. btrfs on the ISO: upstream ISOs support it (profiles/base.nix) vs this repo's ISO (host config),
   both true; the repo's pending host needs the explicit additions.
5. disko pin: lane9 cited 725ea35; this flake pins ff8702b4; corrected.
6. `--disko-mode destroy` documented but rejected by the parser.

## Unresolved / refuted (sources [S20][S25])

- Unresolved: a real ISO boot exercising the gate (needs a hardware round trip); whether the user's
  "first sops store" exists somewhere unreachable; reddit-class sources (anonymous access gated; the
  browsing lanes could not render).
- Refuted: "a custom installer project is needed"; "the sops store must be reused"; `initialPassword`
  as a solution (silently overridden + plaintext); "/run staging" (historical research plus
  unreachable across install).

## Gaps (sources [S9][S25])

- Browsing lanes produced extracted text, not screenshots (child toolset had no browser); a
  provenance gap, not a claim gap.
- The `hardware-enroll` directory defect and the ISO additions are source-verified but not
  boot-tested.
- The lead's own helper script was deleted for a hook policy (triple-quoted data blob); nothing was
  executed from it.

## Expansion trace (sources [S22][S23])

Wave 1: 8 members + 9 lanes, 7 lane returns + 1 member return; 5 members errored at startup (runtime
provider failures), so wave 2 replaced them with lanes 10-14. Leads L1-L31 tracked in
expansion-log.md. Convergence: no new unchecked leads after wave 2; remaining items are user-input
questions or hardware-round-trip verifications.

## Method: how this research was made

- Team: 8 members at creation (one per axis plus a skeptic and a contrarian). Five members errored at
  startup with no transcript (runtime provider failures); those axes were re-covered by replacement
  task lanes. 14 lanes ran in total across two waves.
- Lanes: 2 explore (repo tests; repo history), 5 librarian (nixos-anywhere source; NixOS/sops docs;
  prior art; transport; repo dive), 2 browsing (discourse and GitHub threads, armed with the
  ultimate-browsing skill; they could not render or screenshot, so they returned first-party
  extracted text instead), 3 replacement lanes (repo gaps; password proof; ISO design), 2 attack
  lanes (skeptic; contrarian).
- Waves: wave 1 launched 8 members + 9 lanes in one turn; wave 2 launched the replacement and attack
  lanes and followed each returned lead. Convergence: no new unchecked leads after wave 2.
- Searches: English-first web search across official docs, GitHub sources at pinned SHAs, and
  community threads; repository claims read from the working tree at the session's commits (6992dd2
  and the docs-only 5a33373), with deleted history recovered through the GitHub API.
- Verifications: 7 executed checks by the lead (VA1-VA4 plus eval probes) and lane-executed checks
  (secrets-route's gen_trust runs and the old-disk mount proof); the one mechanism not executed
  end-to-end is a real ISO boot with the autostart gate.
- Debate: the skeptic returned 5 verdicts and the contrarian 5 premise attacks; both changed the
  synthesis (identity preservation, trigger-not-authorization, the ISO kernel-module fix, and the
  downgrade of store reuse from requirement to reframed risk).
- Correction log: the draft treated "reuse the sops store" as a requirement and autostart as core;
  the contrarian's evidence reframed the first and the skeptic's the second. The disko citation was
  corrected to the shipping pin ff8702b4. The btrfs claim was corrected from "btrfs-progs present"
  to "absent on iso.antagony; one-line fix". A lead helper script was deleted for a hook policy and
  two session files were rewritten after a tooling mistake (async read) clobbered them; this
  synthesis is the restored and verified version.
