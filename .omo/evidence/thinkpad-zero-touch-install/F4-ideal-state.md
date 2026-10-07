# F4 — Ideal-state fidelity: `thinkpad-zero-touch-install`

- Plan: `.omo/plans/thinkpad-zero-touch-install.md` (IS-1..IS-7, GAP-1..GAP-7; todos 1-15 + F1-F4)
- Audited tip: `5d4052fe69c268574a8fffda12cc64b72476f44c` (`main` == `thinkpad-zero-touch-install/wave3`)
- Read-only tree: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (`git status --porcelain` empty before/after every probe)
- Evidence dir: `.omo/evidence/thinkpad-zero-touch-install/`; ledger: `.omo/ulw-execute/ledger.jsonl` (80 entries)
- Auditor: F4 ideal-state fidelity (final verification wave). No implementation; the only write is this report.
- Method: for every IS/GAP row, state the claimed behavior, name the code and the QA artifact, and re-run the decisive command for the four load-bearing rows (IS-1 both entry points, IS-2 tree, IS-3 identity/host match, IS-4 inert gate) plus the shared evidence (tests, docs, must-nots).

## Verdict

**APPROVE on the IS/GAP rows.** Every one of IS-1..IS-7 and GAP-1..GAP-7 has a delivering todo, shipped code, and QA
evidence that covers the row; the four load-bearing rows were re-executed by this auditor and pass. No stated
criterion fails.

**One open finding (OF-1) is carried, not a row shortfall:** the *real ISO medium* boot is unverified and the
mechanism evidence says it is likely unbootable as shipped (the `bootstrapPasswordHash` activation has no
installer/variant gate). Per the brief that is an open finding for F4 and the plan's own rule converts it into a
new todo — it is not a compliance failure of todos 1-14, and no IS row's stated proof fails.

---

## 1. IS rows (ideal state)

| IS | Claimed behavior | Shipped behavior (code) | Proving artifact + decisive command | My re-run | Verdict |
| --- | --- | --- | --- | --- | --- |
| IS-1 | `mei` has a working per-install password, shown once, on BOTH entry points (app + operator orchestrator) | `bin/_install-staging.sh:staging_password` (`mkpasswd --method=yescrypt --stdin`, regex-validated **before** write, `0700` dir + `0600` file, printed exactly once, `unset pw`); app `stage_install_payload` (`apps/x86_64-linux/install:448-455`); operator `stage_password_payload` (`bin/host-install.sh:162-196`) | `task-3-*.log` (29 PASS/0 FAIL incl. the real activation validator under `unshare -Ur -m` → rc=0 silent); `task-6-*.log`, `task-15-*.log`; `wave1-verification.json` t3/t5; `wave2-verification*.json` t6/t15 | **re-ran**: helper harness (0700 dir, 0600 file, one LF line, hash matches the validator regex, printed once/24 alnum, no plaintext under the stage) → 23/23 PASS; `install --dry-run` prints the staging step + `--extra-files <stage>` and no secret; `bin/host-install.sh --dry-run --target-host 1.2.3.4` prints the staging step and no secret; `--install-only` prints no staging step; secret scan over all three dry-runs → 0 hits | **PASS** |
| IS-2 | Enrollment artifacts and the age identity persist inside the installed system | `stage_enrollment_artifacts` → `var/lib/nixos-enrollment/<candidate,intake,host-key>` (0700 dir, 0600); `stage_age_identity` → `home/<user>/.config/sops/age/keys.txt` (0600); forwarded as `nixos-anywhere --extra-files <stage> --chown home/<user>/.config <uid>:<gid>` only when the identity subtree was staged (`apps/.../install:404-455,624-641`) | `task-7-*.log` (42 PASS/0 FAIL: full tree layout + modes + warn-and-continue paths + `--save` downgrade); `wave2-verification-r2.json` t7 | **re-ran**: helper harness staging tree → `var/lib/nixos-bootstrap/…hash` (0700/0600), `var/lib/nixos-enrollment/{candidate,intake,host-key}` (0700/0600), `home/mei/.config/sops/age/keys.txt` (0600, `.config` 0700, `home/mei` 0755), content preserved → PASS | **PASS** |
| IS-3 | The only held age identity survives the disk wipe by construction | `--rescue-identity` mounts the live layout read-only (`ro,nologreplay,subvol=/@home`, fallback `subvolid=5`) and copies `keys.txt` into the stage, **dies** if missing, always unmounts (`apps/.../install:531-611`); `--stage-identity` is off by default (`bin/host-install.sh:116-124,184-194`); `verify_host_match` refuses the wrong machine before the wipe (`:461-529`) | `task-8-*.log` (18 PASS/0 FAIL: rescue success + fallback + refusals + no leftover mount; Phase P/E mismatch dies); `wave2-verification-r2.json` t8 | **re-ran**: `install --dry-run --rescue-identity` → adds `5b. rescue mount the live btrfs @home read-only … (dies if the identity is missing)`, no secret; extracted shipped `verify_host_match` harness → 10/10 (Phase P: P52→antagony accepted, unknown DMI dies, wrong `--host` dies; Phase E: identical accepted, `diskById`/`sizeBytes`/`logicalSectorBytes`/`modelSha256`/`serialSha256`/`cpuVendor` mismatches all rejected) | **PASS** |
| IS-4 | A plain boot of the installer ISO touches nothing; installing happens only behind an explicit per-boot opt-in | `modules/flake/iso-images.nix:83-121`: `ConditionKernelCommandLine = "nixos.autoinstall=1"`, `ConditionPathExists = "!/run/autoinstall-done"`, `OnFailure = [ iso-install-rescue.target ]`, `SuccessAction = reboot`; the flag is **never** in `boot.kernelParams` (eval-confirmed) | `task-11-*.log` (wall PASS + negative-assertion flip rc=1 + condition flip rc=1); `task-14-*.log` (twin-boot VM: plainBoot inactive/no marker/data disk untouched; gatedBoot runs → fails cleanly → rescue target); `wave3-verification.json` t11/t14 | **re-ran**: `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'` → `"dendritic-config-eval=PASS"` rc=0; scratch-copy mutation dropping the `!` → assertion failed rc=1; `nix eval` of `isoConfig.{antagony,remembrance}` → `nixos.autoinstall=1` absent from `boot.kernelParams`; `nix build .#iso.{antagony,remembrance} --dry-run` rc=0; **VM re-run: GREEN (§5)** | **PASS** |
| IS-5 | Existing trust gates (`--yes`, live-root, reviewed enrollment) stay intact; the app path additionally gains a host/disk match | `stage_install` re-checks `--yes` before the destructive call (`bin/host-install.sh:325-329`); `require_live_root` in the app (`:643-650`, called at `:657,683`); the attempt marker `: > /run/autoinstall-done` is written immediately **before** the `nixos-anywhere` call (`:349` vs `:351`); `verify_host_match` (Phase P DMI map, Phase E candidate-vs-baked, **no override**) | `task-4-*.log` (marker order + malformed-arg arms); `task-8-*.log`; `task-15-*.log`; F1 §2 Must-NOT audit | **re-ran**: read `stage_install` (`--yes` re-check + marker-before-call); `--install-only` dry-run skips staging; IS-3 harness proves the host/disk match; `grep` shows `nixos.autoinstall=1` only in the unit condition/comments/tests/docs | **PASS** |
| IS-6 | Tests and docs cover the new behavior (ISO autostart included) | `tests/install-staging.sh`, `tests/dendritic-config-eval.nix` (ISO wall), `tests/bootstrap-password-mutations.sh`, `tests/iso-autostart-vm.nix`, all wired in `modules/flake/checks.nix:38-121`; docs in `README.md` + both service notes | `task-10-*.log`, `task-11-*.log`, `task-12-*.log`, `task-13-*.md`; `wave3-verification.json` t10/t11/t13 | **re-ran**: `bash tests/install-staging.sh` → PASS; `bash tests/dendritic-apps.sh` → PASS; `bash tests/bootstrap-password-mutations.sh` → 7 controls PASS / 6 mutants KILLED, rc=0; eval wall PASS; doc greps (`--extra-files`, `nixos.autoinstall=1`, `--rescue-identity`, `--stage-identity`) → PASS; read README §"Auto-install at boot" + the ISO note (flags/unit/target match the code) | **PASS** (NOTE-3) |
| IS-7 | One install medium and one entry point remain | a single app `apps/x86_64-linux/install` + the sourced helper + `bin/host-install.sh`; `flake.iso.<host>` is built from `flake.isoConfig.<host>` (`modules/flake/iso-images.nix:141-142`); no second installer project, no grub patching | F1 §2 item 5 (no `nixosSystem`/`darwinSystem`/`specialArgs` additions; no second entry point); `task-9-*.json` (`isoMatchesIsoConfig=true`) | **re-ran**: `grep` for `nixos-anywhere` → only the app + operator script; `apps/x86_64-linux/` holds one install app; `flake.iso` == `flake.isoConfig`-built iso | **PASS** |

## 2. GAP rows (closed gaps)

| GAP | Claimed gap | How it is closed (code) | Proving artifact | My re-run | Verdict |
| --- | --- | --- | --- | --- | --- |
| GAP-1 | Nothing writes `/var/lib/nixos-bootstrap/mei-password.hash`; the activation validator fails on a fresh install | `staging_password` writes the yescrypt hash into a 0700 dir as a 0600 root file, validated against the module's exact regex first; both entry points stage it (todos 3,4,6,15) | `task-3-*.log` (C8: the real `bootstrapPasswordHash` validator accepts the produced hash, rc=0 silent); `task-6/15`; `wave1-verification.json` t3/t4/t5 | **re-ran**: helper produces the file/modes/regex; read `modules/nixos/bootstrap-password.nix:44-84` — contract is exactly `$y$…` one LF line, `0:0:700` dir, `0:0:600` file | **PASS** |
| GAP-2 | Artifacts leave RAM only via `--save` to external media | `stage_enrollment_artifacts` copies candidate + intake + host key into the stage (0700/0600); `--save` is downgraded to an optional extra copy (todo 7) | `task-7-*.log` (42 PASS: artifacts staged, `--save` warn-not-die, escape hatch still works) | **re-ran**: helper harness stages all three artifacts at 0600 in a 0700 dir; `install --dry-run` lists `var/lib/nixos-enrollment/…` | **PASS** |
| GAP-3 | The age identity exists only on the disk being wiped | `--rescue-identity` reads it off the live `@home` read-only; `stage_age_identity` also accepts `$SOPS_AGE_KEY_FILE`/`~/.config/…`; the operator path adds off-by-default `--stage-identity SRC` (todos 8,9) | `task-8-*.log` (rescue success/fallback/refusal; mount always torn down); `wave2-verification-r2.json` t8 | **re-ran**: rescue dry-run + host-match harness (see IS-3) | **PASS** |
| GAP-4 | No opt-in install path exists | `nixos-autoinstall.service` (gated per boot, inert by default, fails into `iso-install-rescue.target`, host/disk match before any wipe) + the rescue shell on tty1 (todo 9) | `task-9-*.json` (unit fields both hosts); `task-11-*.log`; `task-14-*.log` | **re-ran**: eval wall PASS + negative assertion falsifiable; `nix eval` of the unit fields for both hosts (via the wall) | **PASS** |
| GAP-5 | `iso.antagony` lacks btrfs/vfat support, `btrfs-progs`, and a boot-loaded btrfs module | `modules/flake/iso-images.nix:63-67` (`btrfsSupport`: `boot.supportedFilesystems = [ "btrfs" "vfat" ]`, `boot.kernelModules = [ "btrfs" ]`), added to `extendModules` (todo 2) | `task-2-*.json`; `wave1-verification.json` t2 | **re-ran**: `nix eval` both hosts → `supportedFilesystems=[btrfs,vfat]`, `kernelModules ⊇ btrfs`, `fsPackages ⊇ btrfs-progs` | **PASS** |
| GAP-6 | The ISO writes its enrollment base record into a directory it never creates | `environment.etc."hardware-enrollment/<host>.json".text = baseDeclaration` (`modules/flake/iso-images.nix:56-58`), replacing the runtime `printf` (todo 1) | `task-1-*.json` (both hosts; pre-change negative); `wave1-verification.json` t1 | **re-ran**: `nix eval` the etc text → JSON with `"hostId":"antagony"` at the path the oneshot's `--base` reads | **PASS** |
| GAP-7 | ISO autostart and the staging path have no test coverage | `tests/install-staging.sh` + the ISO eval wall + `tests/bootstrap-password-mutations.sh` + the twin-boot `tests/iso-autostart-vm.nix`, all wired in `checks.nix` (todos 10,11,12) | `task-10/11/12/14-*`; `wave3-verification.json` t10/t11/t14 | **re-ran**: all four suites (install-staging PASS, mutations 6/6 KILLED, eval wall PASS, VM re-run GREEN — §5) | **PASS** |

## 3. Must-NOT / guardrail spot-checks (relevant to the ideal state)

| Check | Command | Result |
| --- | --- | --- |
| `nixos.autoinstall=1` never in `boot.kernelParams` / a unit default | `grep -rn 'nixos.autoinstall' modules/ apps/ bin/ tests/ docs/ README.md`; `nix eval` `isoConfig.<host>.config.boot.kernelParams` | PASS — only the unit's `ConditionKernelCommandLine`, comments, tests, docs; `boot.kernelParams` clean (the sole `boot.kernelParams` use is the test-only override `tests/iso-autostart-vm.nix:99`) |
| No `\|\| true` in the new unit | `awk` over the `nixos-autoinstall` block | PASS — none |
| `--chown` never outside `home/<user>/.config` | `grep -rn -- '--chown' apps/ bin/ modules/` | PASS — app emits only `home/${install_user}/.config`; the operator forwards caller-supplied pairs or the helper-reported `.config` |
| No plaintext password in the diff | `git log -p 5a33373..HEAD \| grep -E 'password for\|AGE-SECRET-KEY\|…'` | PASS — only the format string, prose, and the test-only yescrypt *hash* fixture |

## 4. Overfit / slop and `programming` pass (skills unavailable — criteria applied directly)

`remove-ai-slops` and `programming` are not installed in this session's skill roots (`r0/bundle`, `r1/bun-1-4` only),
so their documented criteria were applied directly to the diff, tests, and production code.

- **Deletion-only / removal-verifying tests:** none. The new tests pin present behavior; none merely asserts that
  something was removed.
- **Tautological tests:** none found. `tests/bootstrap-password-mutations.sh` is a real mutation harness (7 controls
  must pass, 6 mutants must be *killed* — verified rc=1 for all six). The eval wall's negative assertion is
  falsifiable (dropping the `!` → rc=1, re-run by me).
- **Implementation-mirroring tests:** `tests/install-staging.sh` pins literal source tokens (`--method=yescrypt`,
  `unset pw`, `transport+=(--extra-files "$stage")`) and the eval wall pins unit fields. This mirrors implementation,
  but it is exactly what the plan asked for (todo 10/11) and is the repo's established `runCommand`/eval-wall
  convention; it is falsifiable (mutation-proven). Not slop.
- **Excessive tests:** no invariant is duplicated across suites; `install-staging.sh` counts the single
  `password for %s: %s` print precisely to avoid a prose false positive (an anti-tautology guard).
- **Unnecessary production extraction/parsing/normalization:** the helper is the plan-required shared builder, not a
  speculative abstraction (the app and operator both source it; no duplicated hash regex). `dmi_host_for_product`
  and the `verify_host_match` comparison are the plan's stated host/disk guard, not padding.
- **Maintenance burden / false confidence:** the one test that cannot observe the plan's literal expectation
  (`iso-autostart-vm` variant (b) cannot reach the host-match guard offline) is documented honestly in the test
  header — disclosure, not hidden false confidence. The VM's compensating `bootstrapHash` fixture is the one place
  a test could mask a real boot failure: see OF-1/OF-2.
- **Code-review coverage:** `F1-compliance.md` §5 contains the same overfit/slop pass and covers these criteria. The
  dedicated code-review report (`F2-code-quality.md`) is **not present** in the evidence dir at audit time (see
  Evidence gaps); this direct check stands on its own.

## 5. VM re-run (IS-4 / todo 14) — decisive command, executed by this auditor

Command: `cd /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3 && timeout 3000 nix build .#checks.x86_64-linux.iso-autostart-vm --no-link`

**Result: GREEN, re-executed by this auditor at the tip.** `nix build … --no-link --print-out-paths` → rc=0,
out path `/nix/store/2rxmyc2jlfgz2m58imiqqjdg476sgc5q-vm-test-run-iso-autostart-vm` (byte-identical to the path the
independent wave-3 verifier recorded, so the run is reproducible/deterministic). The build log
(`/nix/var/log/nix/drvs/8n/…vm-test-run-iso-autostart-vm.drv.bz2`) shows the decisive lines:

- `plainBoot`: `nixos-autoinstall.service skipped, unmet condition check ConditionKernelCommandLine=nixos.autoinstall=1`
  → the unit never activated; `ActiveState=inactive`, `ConditionResult=no`, rescue target inactive,
  `test ! -e /run/autoinstall-done`, `/dev/vdb` `blkid` empty (nothing written).
- `gatedBoot`: `ConditionResult=yes`; unit ran and failed cleanly (`status=1/FAILURE`, `Result=exit-code`,
  `Triggering OnFailure= dependencies`); `Reached target ISO auto-install rescue (the install attempt failed)` +
  `Started ISO auto-install rescue shell on tty1`; `test ! -e /run/autoinstall-done`; `/dev/vdb` still unformatted;
  journal `Running install for x86_64-linux` + `install: cannot evaluate the flake at /nix/store/qdrbl…-source`
  (the app really started; it dies at its first `nix eval` in the offline sandbox — see OF-4).
- `run the VM test script, in 38.32 seconds` (no fixed sleeps; assertions are `systemctl show`/`wait_for_unit` state checks).

## 6. Open findings (carried, not row shortfalls)

- **OF-1 (F-A) — the real ISO medium's boot is UNVERIFIED; mechanism evidence says it is likely unbootable as
  shipped.** `F-A-attempts.md` records three failed `nix build .#iso.antagony` attempts (xorriso: image ~10.99 GiB >
  free space) → verdict `UNVERIFIABLE-DISK`; a fourth attempt was scheduled after wave-3. I corroborated the
  mechanism at config level in this session: `isoConfig.antagony.config` has `system.nixos.variant_id = "installer"`,
  `system.activationScripts.bootstrapPasswordHash` present, **no variant gate** in
  `modules/nixos/bootstrap-password.nix`, and `boot.initrd.systemd.enable = true` with
  `initrd-nixos-activation.service` — so a fresh ISO boot runs the validator before switch-root with no
  `/var/lib/nixos-bootstrap/mei-password.hash` and aborts (the todo-14 VM observed exactly this before its fixture
  was added). Per the brief this is an open finding, not a compliance failure of todos 1-14; per the plan's rule it
  becomes a **new todo**:
  `- [ ] 16. ISO: make a fresh ISO boot reach multi-user (gate the bootstrapPasswordHash validator on the installer variant, or seed the hash into the ISO), then build and boot the real ISO in QEMU to confirm.`
  Evidence pointer: `.omo/evidence/thinkpad-zero-touch-install/F-A-attempts.md` + the config-level eval above.
- **OF-2 — the twin-boot VM seeds a bootstrap-hash fixture to boot.** `tests/iso-autostart-vm.nix:53` installs a
  throwaway yescrypt hash via an initrd unit so the ISO config reaches stage 2; this faithfully reproduces an
  *installed* machine's boot but masks the *fresh ISO* boot failure (OF-1). Documented in the test header. Not a
  row shortfall (IS-4's stated proof is the gate's inertness), but it is the reason CI cannot see OF-1.
- **OF-3 — `bin/AGENTS.md`'s update is not in the delivered tree.** `AGENTS.md` is excluded repo-wide
  (`.git/info/exclude`), so the updated operator doc (7081 B, 4 `--stage-identity` mentions) exists only in the
  wave-3 worktree; `/home/mei/nixos/bin/AGENTS.md` is the stale pre-work copy. Todo 13's acceptance greps
  (README + service notes) pass and those docs cover every new flag, so IS-6 passes; but if the worktree is removed
  that doc is lost. Action: copy it into `/home/mei/nixos/bin/AGENTS.md`.
- **OF-4 — todo 14's literal acceptance ("the app dies at the host-match check") is not reachable offline.** In the
  VM's network-less sandbox the app dies at its first `nix eval` of the baked flake; the landed test pins the
  reachable observables (unit runs → fails cleanly → rescue target → no disk write → app started). Documented in
  the test header; IS-4's own row proof is unaffected.

## 7. Checked artifact paths

- `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md` (read fully)
- `/home/mei/nixos/.omo/ulw-execute/ledger.jsonl`; `/home/mei/nixos/.omo/ulw-execute/briefs/F4-ideal-state.md`
- `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (read-only, tip `5d4052f`, clean)
- shipped code read: `modules/flake/iso-images.nix`, `modules/flake/checks.nix`, `modules/nixos/bootstrap-password.nix`,
  `bin/_install-staging.sh`, `bin/host-install.sh`, `apps/x86_64-linux/install`, `tests/install-staging.sh`,
  `tests/dendritic-config-eval.nix`, `tests/iso-autostart-vm.nix`, `tests/bootstrap-password-mutations.sh`,
  `README.md`, `docs/service-notes/nixos-anywhere-iso-install.md`
- evidence read: `task-{3,6,7,8,9,10,11,13,14,15}-*`, `wave1-verification.json`, `wave2-verification.json`,
  `wave2-verification-r2.json`, `wave3-verification.json`, `F-A-attempts.md`, `fix-unit-path-*.log`,
  `F1-compliance.md`

## 8. Evidence gaps (exact)

1. **The real ISO boot is unverified** (OF-1): no boot log from `nix build .#iso.antagony` + QEMU exists; three
   build attempts failed on disk space. `F-A-iso-boot-diagnosis.md` (the brief's named artifact) does not exist;
   only `F-A-attempts.md` does.
2. **`F2-code-quality.md` is absent** from `.omo/evidence/thinkpad-zero-touch-install/` at audit time, so the
   independent code-review report's skill-perspective/overfit coverage could not be confirmed; `F1-compliance.md` §5
   carries that coverage and I ran the pass directly.
3. **Todo 3's `unshare -Ur -m` real-validator proof** was not re-executed by me (it is the wave-1 verifier's
   independent run, recorded in `task-3-*.log` C8 and `wave1-verification.json` t3); I re-ran the helper's
   modes/regex/one-print/no-plaintext behavior directly.
4. **The VM check** was re-built GREEN by this auditor at the tip (rc=0, §5); the only environmental note is
   that its gatedBoot variant cannot reach the host-match guard offline (OF-4).


## 9. Gate-review contract

- **recommendation:** APPROVE
- **blockers:** none — no stated IS/GAP criterion fails and no Must-NOT is violated. Each blocker entry would be
  `{violatedCriterion, evidencePointer}`; the list is empty. The one carried item is an *open finding* (OF-1/F-A),
  explicitly not a row shortfall: `{violatedCriterion: "none (open finding OF-1)", evidencePointer:
  ".omo/evidence/thinkpad-zero-touch-install/F-A-attempts.md + config-level eval (variant=installer,
  bootstrapPasswordHash present, no variant gate, initrd-nixos-activation=true)"}`.
- **originalIntent:** the operator's one-pass ThinkPad NixOS install must leave a machine that can actually be
  logged into, carrying its own enrollment record and age identity — with an *opt-in*, per-boot, inert-by-default
  autostart that can never wipe a machine on an accidental boot, and no second install path.
- **desiredOutcome:** restore the lost password step on both entry points, stage the artifacts + age identity into
  the installed system during install (no second USB), make the ISO btrfs-capable and land its enrollment base
  record, add a typed per-boot gated autostart that fails into a rescue shell, and prove it with repo tests, eval
  walls, one VM check, and docs.
- **userOutcomeReview:** the shipped artifact delivers that outcome at the level the plan scopes: a fresh install on
  either entry point mints a validator-conformant yescrypt hash into a tmpfs stage, prints the password once, and
  forwards the stage plus the identity subtree through `nixos-anywhere --extra-files/--chown`; a plain ISO boot
  activates nothing (`ActiveState=inactive`, `ConditionResult=no`, no `/run/autoinstall-done`, data disk untouched)
  while a gated boot runs the unit, fails safely, and reaches the rescue target; the ISO reads btrfs and its
  enrollment JSON lands. The one thing the user still cannot rely on is the *real medium*: OF-1 says the ISO is
  likely unbootable as shipped, which blocks the end-to-end outcome until a new todo fixes and verifies it.
- **checkedArtifactPaths:** see §7.
- **evidenceGaps:** see §8 (exact, four items).

---

F4Report: {"verdict": "APPROVE", "rows": {"IS-1": "PASS", "IS-2": "PASS", "IS-3": "PASS", "IS-4": "PASS", "IS-5": "PASS", "IS-6": "PASS", "IS-7": "PASS", "GAP-1": "PASS", "GAP-2": "PASS", "GAP-3": "PASS", "GAP-4": "PASS", "GAP-5": "PASS", "GAP-6": "PASS", "GAP-7": "PASS"}, "shortfalls": [], "openFindings": ["OF-1 (F-A): real ISO boot UNVERIFIED; mechanism says the ISO is likely unbootable as shipped (bootstrapPasswordHash activation has no installer/variant gate). Open finding, not a todos-1-14 compliance failure; becomes new todo 16."]}
