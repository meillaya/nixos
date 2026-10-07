# Gate review — G009-synthesis-delivery-cited-synthesis-m

- Reviewer role: final gate reviewer (omo-native-gate-reviewer)
- Reviewed at: 2026-10-06
- Attempt dir: `/home/mei/nixos/.omo/evidence/ulw/01a10c8c-59b2-75b2-8449-190d6c9dbba1/G009-synthesis-delivery-cited-synthesis-m/a0`
- Session dir: `/home/mei/nixos/.omo/ulw-research/20261006-100350`
- Deliverable under review: `SYNTHESIS.md` (md) + `report.html` (post)
- Artifact integrity: `SYNTHESIS.md` sha256 `0ee5cb3465bd9362fa206f3e37766e01cde9cf2301e3669df41f4ec166b693dc` and `report.html` sha256 `6f3f5058721c092b86e9fbdd1e2f36d99093bd6767fd491803f1e61ebf183b90` both equal the hashes recorded in this attempt's `data-diff.txt`.

## recommendation

**APPROVE** (no blockers; 6 notes).

The deliverable answers the brief's core question and all five user requirements, every load-bearing
claim is cited to a source or an executed verification, and I independently reproduced the
load-bearing executed verifications (VA2, VA3, VA4-core, VA8, VA1-core), the recovering-commit
claim, the pre-existing defect, the sops-wiring greps, the password override-order claim, and the
static gate. The residual gaps (no ISO boot, no screenshots, untested `mkdir` fix) are honestly
labeled in the deliverable itself. The notes below are documentation-accuracy and provenance items
that do not change any answer or design decision.

## blockers

None. No note below is tied to a stated success criterion of the deliverable's user-visible outcome
(the five requirements, the core question, and honest gap labeling all hold). Each is a hygiene or
provenance gap and is therefore recorded as a NOTE, not a blocker.

## notes (each with a pointer)

- **N1 — Instrumentation counts in the deliverable exceed the shipped instrumentation artifact.**
  `SYNTHESIS.md` / `report.html` ("Epistemic instrumentation" section) state "Claim graph: 12 nodes"
  and "Observation manifest: 24 rows". On disk `claim-graph.md` has 11 node rows and its
  verified-claims digest is still `(none yet)` with every node `unresolved`/`partial` and
  `synthesis location = -`; `observation-manifest.md` has 11 rows (O1–O11). Both files predate the
  wave-2 returns and the synthesis (`claim-graph.md` mtime 10:14, `observation-manifest.md` 10:07;
  wave-2 files 10:20–10:23; synthesis 10:28), and the parent transcript references observation ids
  up to O19, so the files were not synced after wave 2 (the deliverable's own "Method" section
  partly explains this: "two session files were rewritten after a tooling mistake"). This is the
  closest thing to an overstatement in the deliverable; it inflates the apparent instrumentation
  volume in a meta-summary and affects no answer or design decision. Pointer:
  `claim-graph.md`, `observation-manifest.md` (mtime + row counts); deliverable
  "Epistemic instrumentation" paragraph.
- **N2 — Smaller count/label drifts.** Header "Sources: 25 numbered" vs the `sources-ledger.md`
  (28 S-numbers); header "Debate rounds: 10 attack verdicts" vs `debate-log.md` D1–D6 (which does
  cover 5 skeptic + 5 contrarian verdicts across 6 rounds); Method "read from the working tree at
  commit 6992dd2" while HEAD is `5a33373` (a docs-only commit, so code claims are unaffected).
  Pointers: `sources-ledger.md`, `debate-log.md`, `git log --oneline -1`.
- **N3 — Executed-verification provenance for VA1/VA2/VA3/VA8 is summary-level only.** This
  attempt's `cli-transcript.txt` records the raw output for VA4, the static gate, and the outcome
  verify; VA1/VA2/VA3/VA8 raw runs live only in the parent session transcript. I reproduced the
  substance independently (below), so this is a provenance gap, not a claim gap. Pointer:
  `a0/cli-transcript.txt` vs parent transcript.
- **N4 — VA4's full validator run used scratch scripts (`runner.sh` / `validator.sh`) that are not
  archived.** Only the summary remains. I reproduced the mechanism at the regex/message level
  (yescrypt accepted, sha512 rejected, LF=10, and the exact "expected numeric owner 0:0 mode 0600"
  string present in `modules/nixos/bootstrap-password.nix:66`). Pointer: module lines 62–85.
- **N5 — Autostart unit + ISO additions are design/source-verified only (no ISO boot).** This is
  explicitly labeled in the deliverable ("Unresolved: a real ISO boot exercising the gate";
  "source-verified but not boot-tested"), so it is honest, not a gap. Pointer: `SYNTHESIS.md`
  Unresolved/Gaps sections.
- **N6 — Light-lane gates.** `outcome.json` records `gates.layout/visual/proofread = not_run` for the
  `no-format` lane, and `assets/`/`renders/` are empty. The static gate passed (reproduced). The
  post's visual quality is therefore unverified by design, which the lane choice justifies.
  Pointer: `outcome.json`; `defects.json`.

## originalIntent

From `brief.md` and `G009`: turn today's multi-step ThinkPad (`antagony`) install into "boot the ISO
and the install happens", meeting (1) no second USB, (2) a login password that exists after install
(the repo's bootstrap-password contract currently fails on a fresh install), (3) reuse of the sops
material present on this laptop, (4) minimal manual steps on the flake ISO or the official NixOS ISO,
and (5) a verdict on "maybe we need a custom installer?" — delivered as a cited `SYNTHESIS.md` post
plus a closing briefing, with every mechanism claim executed or source-pinned (high precision: a
wrong claim costs a wiped disk or a locked-out machine).

## desiredOutcome

A precise, cited design answer the operator can act on: the minimal mechanism for a zero-touch
install, an explicit statement of what must be carried off the disk before it is wiped, the
autostart safety rule for the ISO, the honest residue for the official ISO, and a build/don't-build
verdict — with gaps labeled rather than hidden.

## userOutcomeReview

I inferred the user's expectation (an actionable, trustworthy answer plus honest uncertainty) and
checked the shipped artifact against it.

1. **Core question + five requirements — satisfied.** Exec summary answer 1 (restore the password
   caller) maps to requirement 2; answer 3 (staging closes no-USB) to requirement 1; answer 2
   (identity preservation) to requirement 3; answer 4 + "Official NixOS ISO: honest residue" to
   requirement 4; answer 5 to requirement 5. Nothing in the brief's scope is dropped.
2. **Every load-bearing claim cited or executed — satisfied.** Password contract/staging: `[S1][S3]`
   + VA4. Password precedence: `[S12][S19]`. `--extra-files` modes: `[S5]` + VA1. btrfs gap:
   `[S6][S15]` + VA2. Silent wipe: `[S13]`. `path:` vs `git+file`: VA3. Identity/gen_trust: VA8
   `[S20][S25]`. Defect: `[S24]`.
3. **Reframing + autostart rule adequately evidenced — yes.** The reframe from "reuse the store" to
   "preserve the identity" rests on reproducible facts I confirmed: nothing in `modules/**` declares
   `sops.secrets` (only `sops.age.sshKeyPaths`); `.sops.yaml`'s `remembrance-keys.yaml` rule
   encrypts to `&admin`+`&recovery` only; the held identity decrypts `github-ssh.yaml` (rc=0); and
   `gen_trust --host antagony` succeeds with no store while `--host remembrance` fails closed. The
   autostart "trigger, not authorization" rule is a design rule sourced to lane12/lane13 and systemd
   docs, resting on the source-pinned no-confirmation wipe fact (`[S13]`); the unexecuted ISO boot is
   labeled.
4. **Residual gaps honestly labeled — yes.** No ISO boot, no browsing screenshots, and the untested
   `mkdir` fix are all stated in the deliverable.
5. **Overstatement — one item, minor (N1).** The instrumentation counts ("12 nodes", "24 rows") are
   not reflected in the shipped `claim-graph.md` / `observation-manifest.md`. It does not inflate any
   factual claim's support.

## checked artifact paths

Session dir `/home/mei/nixos/.omo/ulw-research/20261006-100350/`:

- `brief.md`, `SYNTHESIS.md`, `report.html`, `outcome.json`, `defects.json`, `design-spec.md`
- `claim-graph.md`, `intent-diff.md`, `observation-manifest.md`, `expansion-log.md`,
  `sources-ledger.md`, `design-options.md`, `iso-design.md`
- `excursion-log.md`, `debate-log.md`, `cause-disappearance.md`, `verification-economics.md`
- `wave-1-lane2.md`, `wave-1-lane6.md`, `wave-1-lane9.md`, `wave-1-lane-repo-tests.md`
- `wave-2-lane10-lane11.md`, `wave-2-lane12-lane13.md`, `wave-2-lane14.md`

Attempt dir (above): `cli-transcript.txt`, `data-diff.txt`.

Repo (working tree HEAD `5a33373`):

- `modules/flake/iso-images.nix`, `modules/nixos/bootstrap-password.nix`,
  `modules/aspects/features/sops.nix`, `.sops.yaml`, `apps/x86_64-linux/install`,
  `bin/host-install.sh`, `tests/dendritic-config-eval.nix`, `flake.lock`
- git objects `f7015a56:bin/nixos-anywhere-bootstrap-password.sh`, `d4f2559`
- pinned nixpkgs/nixos at the flake's rev (`/nix/store/398fqjqkp383m7pyla9nxpi1is5vzywh-source`):
  `nixos/modules/config/users-groups.nix`

Parent session transcript: `/home/mei/.omo/agent/sessions/--home-mei-nixos--/2026-10-05T14-51-27-027Z_01a10c8c-59b2-75b2-8449-190d6c9dbba1.jsonl`
(VA1–VA8 references present).

## independent reproduction ledger (this review)

- **VA2 (btrfs) — reproduced exactly.** `.#iso.antagony.passthru.config.boot.supportedFilesystems`
  = `{iso9660,overlay,squashfs,tmpfs}` (no btrfs/vfat); `.#iso.remembrance...` adds `btrfs`+`vfat`.
  `config.system.fsPackages`: antagony = `[dosfstools]`; remembrance = `[dosfstools, mtools,
  btrfs-progs-7.1]`. Kernel `configfile = linux-config-7.2.7` with `CONFIG_BTRFS_FS=m` (version
  7.2.7). `variant_id = "installer"`. Kernel `config.CONFIG_BTRFS_FS` is not exposed in the modern
  structured attrset — the file is `kernel.configfile`, which is what the synthesis cited.
- **VA4 core — reproduced.** `mkpasswd --method=yescrypt --stdin` output matches the module regex
  `^\$y\$[./A-Za-z0-9]+\$[./A-Za-z0-9]{1,86}\$[./A-Za-z0-9]{43}$`; a sha512 hash is rejected; last
  byte = 10; the message string "expected numeric owner 0:0 mode 0600" exists at
  `bootstrap-password.nix:66`.
- **VA3 — reproduced.** In a scratch git flake, `builtins.pathExists ./untracked.txt` evaluates
  `true` under `path:` and `false` under `git+file:`.
- **VA8 — reproduced.** `PYTHONPATH=. python3 -B scripts/hardware/gen_trust.py --host antagony` →
  rc=0, emits a trust document (fleet fallback, no store); `--host remembrance` → rc=1 with
  "failed to decrypt secrets/remembrance-keys.yaml ... restore the operator secrets".
- **VA1 core — reproduced.** `tar -cpf - . | (umask 022; tar -xpf - --no-same-owner)` preserves a
  0700 dir and a 0600 file exactly as non-root.
- **Static gate — reproduced.** `report-tools.mjs check report.html --design-spec design-spec.md` →
  exit 0, PASS, 0 blocker/major/minor; `report-tools.mjs outcome verify --session-dir .` → OK,
  problems `[]`.
- **Recovered script — reproduced from git.** `git show f7015a56:bin/nixos-anywhere-bootstrap-password.sh`
  exists locally and contains `install -d -m 700 var/lib/nixos-bootstrap`, the SHA-pinned
  `mkpasswd --method=yescrypt`, `chmod 600`, the yescrypt regex, and
  `--extra-files "$stage" --chown var/lib/nixos-bootstrap 0:0`.
- **Pre-existing defect — reproduced.** `modules/flake/iso-images.nix:44` is the only writer of
  `/etc/hardware-enrollment/<host>.json` and nothing creates `/etc/hardware-enrollment`; the script's
  `|| true` covers only the final `nix-auto-enroll` call.
- **sops wiring — reproduced.** Only `sops.age.sshKeyPaths` in `modules/aspects/features/sops.nix`;
  no `sops.secrets` anywhere in `modules/**`; `secrets/remembrance-keys.yaml` absent; held identity
  decrypts `github-ssh.yaml` (rc=0, private key not printed).
- **Password precedence — reproduced.** Pinned nixpkgs `users-groups.nix:61`:
  `overrideOrderMutable = initialHashedPassword -> initialPassword -> hashedPassword -> password ->
  hashedPasswordFile` (hashedPasswordFile wins). `tests/dendritic-config-eval.nix:232` pins
  `hashedPasswordFile`. No password/extra-files references in `apps/x86_64-linux/install` or
  `bin/host-install.sh`; the latter's nixos-anywhere call passes no `--extra-files`.
- **Pins — reproduced.** `flake.lock` disko = `ff8702b4…` (matching the synthesis's correction); ISO
  drv versions `26.11.20260923.4975466` match the cited nixpkgs rev.

## remove-ai-slops / programming pass

No production code or test code was changed by this run (research-only deliverable: `SYNTHESIS.md`
prose plus `report.html`). Applied directly:

- No excessive/useless/deletion-only/tautological tests and no implementation-mirroring tests exist
  to flag (none were authored).
- No unnecessary production extraction/parsing/normalization was added (no code).
- The deliverable's executed checks are genuine can-fail assertions (the VA4 negative controls —
  mode-644 and sha512 — reject correctly), so they are not tautologies.
- The one false-confidence item is N1 (instrumentation counts exceeding the shipped files); it is a
  documentation-accuracy defect, not a claim-support defect.

The task inputs mention a separate code-review report and a manual QA matrix; neither exists for
this research run (no code, no UI). I performed the skill-perspective check directly above rather
than relying on the executors' coverage statements.

## evidence gaps (exact)

1. No archived raw run for VA1/VA2/VA3/VA8 in the session dir (VA1/VA2/VA3/VA8 raw output is only in
   the parent transcript; this attempt's `cli-transcript.txt` covers VA4 + static gate + outcome
   verify). Substance re-verified here.
2. VA4's full validator harness (`runner.sh`, `validator.sh`, fake-shadow fixture) is not archived;
   only the summary remains. Regex/message-level re-verified here.
3. `claim-graph.md` verified-claims digest is empty and its nodes are stale; `observation-manifest.md`
   is 11 rows vs the deliverable's "24 rows" (N1).
4. No ISO boot was executed for the autostart gate, the `kernelModules`/`supportedFilesystems`
   additions, or the `mkdir -p` fix (label present in the deliverable; the mechanism is unexecuted
   end-to-end).
5. Browsing lanes produced extracted text, not screenshots (provenance gap; labeled).
6. `assets/` and `renders/` are empty; layout/visual/proofread gates are `not_run` (light lane).
