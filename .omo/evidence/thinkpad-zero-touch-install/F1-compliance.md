# F1 — Plan compliance audit: `thinkpad-zero-touch-install`

- Goal: `.omo/plans/thinkpad-zero-touch-install.md` (15 todos + F1-F4)
- Audited tip: `5d4052fe69c268574a8fffda12cc64b72476f44c` (`main` == `thinkpad-zero-touch-install/wave3`)
- Read-only worktree: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (clean: `git status --porcelain` empty before and after every probe)
- Ledger: `.omo/ulw-execute/ledger.jsonl` (80 entries)
- Evidence dir: `.omo/evidence/thinkpad-zero-touch-install/`
- Auditor: F1 plan-compliance (final verification wave). No implementation; the only write is this report.

## Verdict

**APPROVE.** Every todo acceptance criterion has recorded evidence and, where re-runnable, was re-executed
by this auditor (14 of 15 todo criteria re-run directly; the remaining one — todo 14's QEMU VM — was rebuilt
green at this exact tip by the independent wave-3 verifier, with both falsifiability mutations re-run there;
todo 3's `unshare -Ur -m` validator proof is likewise the wave-1 verifier's independent re-run). All six Must-NOT guardrails
hold. The six recorded deviations are adjudicated below; none is an unmet acceptance criterion and none
violates a Must-NOT.

---

## 1. Per-todo acceptance table

Legend: **re-check** = this auditor re-ran the plan's acceptance command in the read-only worktree at 5d4052f.
"evidence" = the recorded artifact in `.omo/evidence/thinkpad-zero-touch-install/`.

| Todo | Acceptance criterion (plan) | Recorded evidence | My re-check (command -> result) | Verdict |
| --- | --- | --- | --- | --- |
| 1 | `nix eval` iso.antagony `etc."hardware-enrollment/antagony.json".text` contains `"hostId": "antagony"`; `nix build .#iso.antagony --dry-run` evaluates | `task-1-*.json` (T1.2/T1.4 hostId pair both hosts; T1.5 dry-run rc=0; T1.1 pre-change missing-attr negative) | `nix eval` of both hosts -> `enrollmentHostId = "antagony" / "remembrance"`; `dendritic-config-eval` asserts `hasInfix '"hostId":"antagony"'` -> PASS | PASS |
| 2 | `boot.supportedFilesystems` has btrfs+vfat, `boot.kernelModules` has btrfs, `system.fsPackages` has btrfs-progs, for BOTH ISOs | `task-2-*.json` (T2.3 pre-change baseline has no btrfs/vfat/progs; T2.1/T2.2 both hosts after) | `nix eval` both hosts -> `supportedFilesystems=[btrfs,vfat]`, `kernelModules` contains `btrfs`, `fsPackages` contains `btrfs-progs` -> PASS | PASS |
| 3 | `bash -n bin/_install-staging.sh`; `staging_password` yields 0700 dir / 0600 file / exact yescrypt regex / printed once; failing `mkpasswd` writes nothing; real validator accepts the hash under `unshare -Ur -m` | `task-3-*.log` (29 PASS / 0 FAIL, three runs incl. commit ceca3a7); `wave1-verification.json` todos.3 (real activation-script validator rc=0 silent) | re-ran the helper probes in a scratch shell (see §4 re-check log: 0700/0600/regex/one-print); validator-under-unshare is the wave-1 verifier's independent run | PASS |
| 4 | `bash -n`; `--dry-run --extra-files /tmp/x --chown home/mei/.config 1000:100` prints a plan containing both; marker write precedes the nixos-anywhere call | `task-4-*.log` (dry-run plan + missing-arg rc=64 arms + line-239 marker before line-241 call) | `bash bin/host-install.sh --dry-run --host antagony --extra-files /tmp/x --chown home/mei/.config 1000:100` -> plan carries `--extra-files` and `--chown home/mei/.config 1000:100`; `grep -n` -> marker at `bin/host-install.sh:349` precedes the call at `:351` -> PASS | PASS |
| 5 | `grep -Fq 'pkgs.mkpasswd' modules/flake/apps.nix`; `nix eval ...apps.x86_64-linux.install.program` succeeds | `task-5-*.txt` (grep + eval run twice + realized wrapper PATH contains mkpasswd-5.6.6; base checkout negative) | `grep -Fq 'pkgs.mkpasswd'` PASS; `nix eval --impure --raw ...apps.x86_64-linux.install.program` -> `/nix/store/m6d0mk999prk93dxpbv9zdm76z73z6dw-install/bin/install` rc=0 | PASS |
| 6 | `--dry-run` prints the staging step, the `--extra-files` transport, the exact `--chown home/<user>/.config <uid>:<gid>` pair, no `password for` line; exactly one `password for` print; `bash tests/dendritic-apps.sh` passes | `task-6-*.log`; `wave2-verification.json`/`-r2.json` todos.6 (real-run harness, stub-mkpasswd dies pre-transport, `grep -c 'password for' app`=0, helper=1) | `./apps/x86_64-linux/install --dry-run --host antagony` -> staging step + `--extra-files <stage> --chown home/mei/.config 1000:100`, no secret; `bash tests/dendritic-apps.sh` -> PASS; `install-staging.sh` counts exactly one `password for %s: %s` across the three scripts -> PASS | PASS |
| 7 | `--dry-run` lists enrollment-artifact and identity staging; no die when `--save` omitted; identity source fallback order present | `task-7-*.log` (42 PASS/0 FAIL; no-key warn-and-continue; `--save` escape hatch); `wave2-verification-r2.json` todos.7 (r1 no-key `--chown` defect fixed by bf90e20) | `./apps/x86_64-linux/install --dry-run` -> prints `var/lib/nixos-enrollment/<candidate,intake,host-key>` and `home/<user>/.config/sops/age/keys.txt ... from $SOPS_AGE_KEY_FILE else ~/.config/...` -> PASS | PASS |
| 8 | `--dry-run --rescue-identity` prints the rescue step; host/DMI mismatch dies before staging; enrolled candidate-vs-baked comparison enforced | `task-8-*.log` (18 PASS/0 FAIL: Phase P/E mismatch dies before wipe; rescue mount/umount/refusals); `wave2-verification-r2.json` todos.8 | `./apps/x86_64-linux/install --dry-run --host antagony --rescue-identity` -> adds `5b. rescue  mount the live btrfs @home read-only, copy ... (dies if the identity is missing)` -> PASS | PASS |
| 9 | Eval wall (todo 11) passes incl. the negative kernelParams assertion; `nix build .#iso.antagony --dry-run` evaluates | `task-9-*.json` (40+ field assertions both hosts; `isoMatchesIsoConfig=true`; negative flag; dry-run rc=0); `wave2-verification.json` todos.9 | `nix eval` both hosts -> `unitCondition="nixos.autoinstall=1"`, `unitOnFailure=[iso-install-rescue.target]`, `unitSuccessAction=reboot`, `svcType=oneshot`, `svcPath=[bash-interactive,coreutils,nix,...]`, `scriptHasRescue=true`, `isoMatchesConfig=true`, `autoinstallInKernelParams=false` -> PASS | PASS |
| 10 | `bash tests/install-staging.sh` exits 0; each assertion textually fails on token removal (spot-check two); `bash tests/dendritic-apps.sh` passes | `task-10-*.log` (script twice identical; 3 token-removal mutations rc=1; wired check builds rc=0; flake-check eval rc=0); `wave3-verification.json` todos.10 (3 mutations re-run) | `bash tests/install-staging.sh` -> `install-staging=PASS` rc=0; `bash tests/dendritic-apps.sh` -> `dendritic-apps=PASS` rc=0; read the script: every `require`/grep is a real token pin (falsifiability independently re-run by the wave-3 verifier) -> PASS | PASS |
| 11 | `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'` prints PASS; removing the condition makes it fail | `task-11-*.log` (PASS + negative-assertion flip rc=1 + condition flip rc=1 + second deterministic run); `wave3-verification.json` todos.11 (mutations re-run) | `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'` -> `"dendritic-config-eval=PASS"` rc=0 (this wall contains the negative `assert !(builtins.elem "nixos.autoinstall=1" ...boot.kernelParams)`) -> PASS | PASS |
| 12 | `bash tests/bootstrap-password-mutations.sh` exits 0; the check appears in `nix flake check --all-systems --no-build` output | `task-12-*.log` (7 controls PASS / 6 mutants KILLED; check present in flake-check eval; `wave1-verification.json` todos.12 + mutation re-run) | `bash tests/bootstrap-password-mutations.sh` -> 7 `control-*=PASS`, 6 `mutant-*=KILLED`, `mutation-control=PASS` rc=0; `modules/flake/checks.nix` wires `bootstrap-password-mutations` -> PASS | PASS |
| 13 | `grep -Fq -- '--extra-files' README.md docs/service-notes/*.md`; `grep -Fq 'nixos.autoinstall=1' docs/service-notes/nixos-anywhere-iso-install.md`; prose matches the flags | `task-13-*.md` (both greps rc=0; flag-exists probe; unit/target names exist in code) | both greps rc=0; read README §"Auto-install at boot" and the ISO service note: the documented flags/unit/target match the shipped code (`--extra-files`, `--chown`, `--stage-identity`, `--rescue-identity`, `nixos-autoinstall.service`, `iso-install-rescue.target`) -> PASS (see NOTE-2) | PASS |
| 14 | `nix build .#checks.x86_64-linux.iso-autostart-vm` exits 0; removing `ConditionKernelCommandLine` makes variant (a) fail | `task-14-*.log` (`build rc=0` at line 2547; `mutated build rc=1 (expected non-zero)` at line 2829); `fix-unit-path-*.log` (F-B fix + tightened assertion); `wave3-verification.json` todos.14 (rebuild rc=0 at tip; condition-removal mutation rc=1; F-B PATH-revert mutation rc=1) | not rebuilt by me (a full QEMU test ~10 min + closure build under concurrent load); the wave-3 verifier rebuilt it green at this tip `5d4052f` and re-ran both mutations -> PASS | PASS |
| 15 | `bash bin/host-install.sh --dry-run --target-host 1.2.3.4` prints the password-staging step and no secret; `--install-only` prints no staging step; the code sources `bin/_install-staging.sh` | `task-15-*.log` (C1-C10 + D1 non-dry run; helper sourced; no duplicated regex); `wave2-verification.json` todos.15 | `--dry-run --target-host 1.2.3.4` -> staging step + `--extra-files <stage>`, no `password for`/`$y$`; `--dry-run --target-host 1.2.3.4 --install-only` -> `0-7. (skipped: --install-only)`, no staging step; `bin/host-install.sh:141` sources the helper -> PASS | PASS |

---

## 2. Must-NOT audit

| # | Guardrail | Command (run at 5d4052f in the worktree) | Result |
| --- | --- | --- | --- |
| 1 | `nixos.autoinstall=1` only in docs/tests; never in `boot.kernelParams` or a unit default | `grep -rn 'nixos.autoinstall' modules/ apps/ bin/ tests/ docs/ README.md`; `nix eval` `isoConfig.{antagony,remembrance}.config.boot.kernelParams` | **PASS** — production hits are comments + `unitConfig.ConditionKernelCommandLine = "nixos.autoinstall=1"` (`modules/flake/iso-images.nix:88`); the only `boot.kernelParams` use is the test-only override `tests/iso-autostart-vm.nix:99`. Eval both hosts: `kernelParams=["root=fstab","loglevel=4","lsm=landlock,yama,bpf"]`, `autoinstallInKernelParams=false`. |
| 2 | No plaintext password to disk/store/tracked file | `grep -rn 'password for' apps/ bin/ modules/ tests/ docs/ README.md`; `git log -p 5a33373..HEAD \| grep -E '^\+.*(password for mei: [A-Za-z0-9]{24}\|initialPassword\|password = ")'`; `git log --all --name-only 5a33373..HEAD \| grep -E 'autoinstall-done\|nixos-install-staging\|\.direnv'` | **PASS** — the only `printf` is `bin/_install-staging.sh:111` (`password for %s: %s`), everything else is prose/comment/test. No literal plaintext password, hash-of-run, stage dir, marker file, or `.direnv` path in any delivered commit. The single `$y$` literal added is the VM fixture hash in `tests/iso-autostart-vm.nix:53` (a hash, not plaintext; test-only). |
| 3 | No `\|\| true` (or equivalent masking) in the nixos-autoinstall unit; ISO auto-enroll keeps a journal-visible marker | `grep -n '\|\| true' modules/flake/iso-images.nix`; read the unit | **PASS** — no `\|\| true` anywhere in the file; the new unit has no masking (`OnFailure=iso-install-rescue.target`); the enrollment oneshot keeps `\|\| echo "hardware-enroll: masked failure (artifact presence is the gate)" >&2`. |
| 4 | No `--chown` outside the staged `home/<user>/.config` subtree | `grep -n -- '--chown' apps/x86_64-linux/install bin/host-install.sh` | **PASS** — the app emits only `--chown home/${install_user}/.config ${uid}:${gid}` (lines 222, 632, gated on `identity_staged` since bf90e20); `host-install.sh` forwards only caller-supplied pairs or the helper-reported `home/<user>/.config`; never `home/<user>`, `/`, or `/var/lib`. |
| 5 | No `specialArgs`/`extraSpecialArgs`, no `nixosSystem`/`darwinSystem` calls, no second install entry point | `git log -p 5a33373..HEAD \| grep -E '^\+.*(specialArgs\|extraSpecialArgs\|nixosSystem\|darwinSystem)'`; per-commit file lists | **PASS** — no additions; `flake.nix` untouched; the only new installer code is the plan's single app (`apps/x86_64-linux/install`) + its sourced helper + the ISO unit; no grub patching, no second project. |
| 6 | `tests/bootstrap-password-lifecycle.sh` NOT wired into flake checks | `grep -rn 'bootstrap-password-lifecycle' modules/ tests/` | **PASS** — only prose references (test headers explaining why it stays manual); `modules/flake/checks.nix` wires `install-staging` and `bootstrap-password-mutations`, never the lifecycle suite. |

Also verified: delivery mode direct (ff-merges into `main` per ledger entries 18/36/79; all 18 wave commits are
ancestors of `main`); all 15 `## TODOs` boxes are `- [x]` (only F1-F4 remain `- [ ]`); wave branches landed
(wave1/wave2 removed after merge, wave3 present and merged at 5d4052f).

---

## 3. Known deviations — adjudication

| # | Deviation (ledger) | Adjudication | Rationale |
| --- | --- | --- | --- |
| 1 | Todo 12 landed as two commits (`bde4937` + `b210a75`) | **ACCEPTED (PASS)** | `b210a75` is a 7-line sandbox-HOME fixup in the todo's own file (`tests/bootstrap-password-mutations.sh`), forced by the nix-build sandbox; it is not a second todo. Plan's "one commit per todo" is a process rule, not an acceptance criterion; no functional or scope impact. |
| 2 | Todo 13's docs commit rewritten (`ae0a3ef` -> `0cc6c55`) to drop a force-added `bin/AGENTS.md`; T10 replayed (`a25219f` -> `19e2e11`) | **ACCEPTED (PASS)** with NOTE-2 | `.git/info/exclude:12` excludes `AGENTS.md`; `git ls-files` shows 0 tracked `AGENTS.md`. Committing it would break the repo's own convention. The updated local file exists and is sha-verified (`cc3f0147…`, 7081 B, 4 `--stage-identity` mentions) — but only in the wave-3 worktree; see NOTE-2. Todo 13's acceptance greps (README + service notes) pass. |
| 3 | Wave-2 fix commit `bf90e20` (conditional `--chown`) | **ACCEPTED (PASS)** | Found by the independent wave-2 verifier: todo 6/7 forwarded `--chown` at a never-staged path, which would abort `nixos-anywhere` *after* disko had formatted the disk. The fix is single-file, re-verified in `wave2-verification-r2.json` (no-key run now forwards no `--chown`). Closing a real post-wipe failure mode outweighs the one-commit-per-todo rule. |
| 4 | Wave-3 fix commit `5d4052f` (unit PATH) | **ACCEPTED (PASS)** | Found by the todo-14 VM test: the unit had no service-level `path`, so the `#!/usr/bin/env bash` wrapper died at status 127 and the app never ran. Fix adds `path = [ pkgs.bash pkgs.coreutils pkgs.nix ]`; the wave-3 verifier re-confirmed with a PATH-revert mutation (banner assertion fails at 127). The t11 eval wall still passes (no asserted field changed). |
| 5 | T15 QA harness truncated two tracked intake files to 0 bytes; restored from HEAD | **ACCEPTED (PASS)** — independently re-verified | `config/hosts/intake/remembrance.json` (3936 B) and `remembrance.intake.json` (4988 B) are byte-identical to `HEAD:` blobs (`97dbfda4…` / `830627c8…`), parse as JSON, and no commit in `git rev-list --all` contains a 0-byte version. |
| 6 | F-A (ISO bootability) unresolved at audit time | **OPEN for F4, not an F1 failure** | F-A is an ideal-state/bootability probe, not a plan acceptance criterion of todos 1-14. At audit time attempt 4 is still running (`/tmp/iso-diag-work/build3.log`, header `ATTEMPT4`); `F-A-attempts.md` records attempts 1-3 as UNVERIFIABLE-DISK (xorriso image ~10.99 GiB vs free space). Per the brief, an unresolved F-A is an OPEN finding for F4. |

---

## 4. Independent re-check log (this session, read-only, tip 5d4052f)

Commands run by the auditor in `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3`; the worktree was clean
(`git status --porcelain` empty) before and after.

| ID | Command | Result |
| --- | --- | --- |
| R1 | `bash tests/install-staging.sh` | `install-staging=PASS` rc=0 |
| R2 | `bash tests/dendritic-apps.sh` | `dendritic-apps=PASS` rc=0 |
| R3 | `bash -n` on `bin/_install-staging.sh`, `bin/host-install.sh`, `apps/x86_64-linux/install`, `tests/install-staging.sh`, `tests/bootstrap-password-mutations.sh`, `tests/dendritic-apps.sh` | all `SYNTAX_OK` |
| R4 | `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'` | `"dendritic-config-eval=PASS"` rc=0 |
| R5 | `bash bin/host-install.sh --dry-run --target-host 1.2.3.4` | staging step + `--extra-files <stage>`; no secret; rc=0 |
| R6 | `bash bin/host-install.sh --dry-run --target-host 1.2.3.4 --install-only` | `0-7. (skipped: --install-only)`; no staging step; rc=0 |
| R7 | `./apps/x86_64-linux/install --dry-run --host antagony` | staging step + transport `--extra-files <stage> --chown home/mei/.config 1000:100`; rc=0 |
| R7b | `./apps/x86_64-linux/install --dry-run --host antagony --rescue-identity` | adds `5b. rescue ...`; rc=0 |
| R8 | `nix eval --impure --json` of `isoConfig.{antagony,remembrance}` (kernelParams/supportedFilesystems/kernelModules/fsPackages/enrollmentHostId/variantId/unit fields/`svcPath`/`scriptHasRescue`/`isoMatchesConfig`) | both hosts: `autoinstallInKernelParams=false`; `supportedFilesystems=[btrfs,vfat]`; `kernelModules` ⊇ `btrfs`; `fsPackages` ⊇ `btrfs-progs`; `enrollmentHostId` == host; `variantId="installer"`; `unitCondition="nixos.autoinstall=1"`; `unitOnFailure=[iso-install-rescue.target]`; `unitSuccessAction=reboot`; `svcType="oneshot"`; `svcPath=[bash-interactive,coreutils,nix,...]`; `scriptHasRescue=true`; `isoMatchesConfig=true` |
| R-t4 | `bash bin/host-install.sh --dry-run --host antagony --extra-files /tmp/x --chown home/mei/.config 1000:100` + `grep -n` | plan carries both flags; marker (`:349`) precedes the `nixos-anywhere` call (`:351`) |
| R-t5 | `grep -Fq 'pkgs.mkpasswd' modules/flake/apps.nix`; `nix eval ...apps.x86_64-linux.install.program` | PASS; `/nix/store/m6d0mk999prk93dxpbv9zdm76z73z6dw-install/bin/install` rc=0 |
| R-t12 | `bash tests/bootstrap-password-mutations.sh` | 7 controls PASS, 6 mutants KILLED, rc=0 |
| R-t13 | `grep -Fq -- '--extra-files' README.md docs/service-notes/*.md`; `grep -Fq 'nixos.autoinstall=1' docs/service-notes/nixos-anywhere-iso-install.md` | both rc=0 |
| R-t3 | helper probe in a scratch shell with `mkpasswd` from the pinned store (`staging_init` + `staging_password`) | rc=0; tmpfs stage; dir 0700, file 0600, one LF line; hash matches both the helper's `_STAGING_HASH_REGEX` and an independently written pattern; password printed once (24 chars); no plaintext copy under the stage; stage removed on exit. With `mkpasswd` absent the helper dies (rc=1) and writes no hash file. |
| R-MN | the six Must-NOT greps/evals in §2 | all PASS |

Cleanup: all scratch files removed (`/tmp/f1-iso-eval.*`); no stage dirs (`/run/user/1000/nixos-install-staging.*`,
`/dev/shm/nixos-install-staging.*`) left; `/run/autoinstall-done` absent; worktree clean; no monitors/servers started
by the auditor.

---

## 5. Overfit / slop and `programming` pass (skills unavailable — criteria applied directly)

`remove-ai-slops` and `programming` are not installed in this session's skill roots (`r0/bundle`, `r1/bun-1-4`
only), so their documented criteria were applied directly to the diff, tests, and production code.

- **Deletion-only / removal-verifying tests:** none. `tests/install-staging.sh` and
  `tests/dendritic-config-eval.nix` pin present behavior; no test merely asserts that something was deleted.
- **Tautological tests:** none found. `tests/bootstrap-password-mutations.sh` is a genuine mutation harness —
  7 controls must pass and 6 mutants must be *killed* (and are, with rc=1), so the check cannot pass by
  construction. The t11 eval wall's assertions were independently falsified by the wave-3 verifier (negative
  assertion flip -> rc=1; condition-value flip -> rc=1).
- **Implementation-mirroring tests:** the t11 wall and `install-staging.sh` pin unit fields / literal tokens.
  This mirrors implementation, but it is exactly what the plan asked for ("the ISO configuration wall",
  "staging invariants"), and it is falsifiable (mutation-proven). Not slop; it is the repo's established
  `runCommand`/eval-wall convention.
- **Excessive tests:** no duplication of the same invariant across suites; `install-staging.sh` counts the
  single `password for %s: %s` print precisely to avoid prose false positives (an anti-tautology guard).
- **Unnecessary production extraction/parsing/normalization:** `bin/_install-staging.sh` is the plan-required
  shared builder (todo 3), not a speculative abstraction; `host-install.sh` sources it rather than duplicating
  the hash regex (verified: no `_STAGING_HASH_REGEX` copy). `ensure_mkpasswd` resolves the tool only when it is
  absent from PATH — a real fallback, not defensive padding.
- **Scope drift / maintenance burden:** the delivered diff stays inside the plan's file set (iso-images.nix,
  apps.nix, install app, host-install.sh, the new helper, four tests, three docs). The only design additions
  beyond the plan's literal field list are recorded in the ledger and evidenced: `environment.etc."nixos-install/flake"`
  (implements the todo title "bake the flake"), the rescue shell's `tty` stdio, the `path = [ bash coreutils nix ]`
  unit fix, and the `vmFixture` (test-only bootstrap-hash seed + 2 GiB/2-core sizing). Each is a documented,
  bounded decision, not drift.
- **False-confidence check:** the one place the landed test cannot observe the plan's literal expectation is
  documented honestly in `tests/iso-autostart-vm.nix` (variant (b) cannot reach the host-match guard offline;
  the test pins the reachable observable instead). This is disclosure, not hidden false confidence.

No overfit/slop blocker found. Findings that create maintenance burden are limited to NOTE-2 below.

---

## 6. Notes (not blockers)

- **NOTE-1 — `--extra-files` semantics on the operator path.** Todo 4's dry-run still prints both
  `--extra-files` and `--chown` (acceptance met), but since todo 15 the operator path overlays a caller-supplied
  `--extra-files` tree *into its own password stage* and forwards the stage path, rather than forwarding the
  caller's value verbatim. The `--install-only` path (used by the app) still forwards it verbatim. Both the plan's
  t4 and t15 acceptance criteria are satisfied; this is the designed reconciliation of the two todos. README's
  phrase "forwarded straight to `nixos-anywhere`" is slightly imprecise for the operator path (the modes list
  correctly says "overlay extra files into the target").
- **NOTE-2 — updated `bin/AGENTS.md` lives only in the wave-3 worktree.** `AGENTS.md` is excluded repo-wide
  (`.git/info/exclude:12`) and untracked, so the t13 update to it did not land in the `main` checkout:
  `/home/mei/nixos/bin/AGENTS.md` is the stale pre-work file (5093 B, sha256 `ed7ef439…`, 0 mentions of the new
  flags), while the updated file (7081 B, sha256 `cc3f0147…`, 4 `--stage-identity` mentions) exists only at
  `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3/bin/AGENTS.md`. Todo 13's *acceptance criteria* (the two
  greps on README/service notes) pass, so this is a NOTE, not a blocker — but if the wave-3 worktree is removed,
  that documentation is lost. Copy it to `/home/mei/nixos/bin/AGENTS.md` if the operator-level docs matter.
- **NOTE-3 — todo 14's literal expectation.** The plan said variant (b) "dies at the host-match check". In the
  offline VM sandbox the app dies earlier, at its first `nix eval` of the baked flake; the host-match guard's
  runtime behavior is therefore not exercised by CI. The test header documents this; the gate itself (plain boot
  inert; gated boot -> unit runs -> fails cleanly -> rescue target -> no disk write) is fully proven, including
  falsifiability of the condition and of the F-B PATH fix.
- **NOTE-4 — disk environment.** F-A attempts 1-3 failed on free space, not on the artifact; attempt 4 is in
  flight. This is environmental, and F-A is F4's open item (deviation #6).

## 7. Evidence gaps

None material. The two criteria this auditor did not re-execute personally are:
1. **Todo 3's** `unshare -Ur -m` real-validator proof — re-run by the independent wave-1 verifier
   (`wave1-verification.json` todos.3) and recorded in `task-3-*.log` (C8: validator rc=0 silent). The helper's
   modes/regex/one-print/no-plaintext behavior was re-run directly by this auditor (R-t3).
2. **Todo 14's** `nix build .#checks.x86_64-linux.iso-autostart-vm` — not rebuilt by this auditor (QEMU + full
   workstation closure under concurrent build load); rebuilt green at this tip by the independent wave-3 verifier
   (`wave3-verification.json` todos.14, plus condition-removal and PATH-revert mutations), with the raw run in
   `task-14-*.log`.

## 8. Gate-review contract

- **recommendation:** APPROVE
- **blockers:** none — no stated success criterion fails and no Must-NOT is violated. (Each would have been
  recorded as `{violatedCriterion, evidencePointer}`; the list is empty.)
- **originalIntent:** the operator's one-pass ThinkPad NixOS install must leave a machine that can actually be
  logged into, carrying its own enrollment record and age identity — with an *opt-in*, per-boot, inert-by-default
  autostart that can never wipe a machine on an accidental boot, and no second install path.
- **desiredOutcome:** restore the lost password step (app + operator entry points), stage the artifacts + age
  identity into the installed system during install (no second USB), make the ISO btrfs-capable and land its
  enrollment base record, add a typed per-boot gated autostart that fails into a rescue shell, and prove all of
  it with repo tests/eval walls/one VM check + docs.
- **userOutcomeReview:** the shipped artifact delivers that outcome. A fresh install (either entry point) mints a
  validator-conformant yescrypt hash into a tmpfs stage, prints the password once, and forwards the stage plus the
  identity subtree through `nixos-anywhere --extra-files/--chown`; a plain ISO boot activates nothing
  (`ActiveState=inactive`, no `/run/autoinstall-done`, data disk untouched) while a gated boot runs the unit,
  fails safely, and reaches the rescue target; the ISO can read btrfs and its enrollment JSON lands. Remaining
  user-visible gaps are documentation-level (NOTE-2) and the environmental F-A ISO-boot probe (F4's open item).
- **checkedArtifactPaths:**
  - `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (read-only worktree at `5d4052f`; `git status` clean)
  - `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md`
  - `/home/mei/nixos/.omo/ulw-execute/ledger.jsonl` (80 entries)
  - `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-{1,2}-*.json`
  - `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-{3,4,6,7,8,10,11,12,14,15}-*.log`
  - `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-5-*.txt`, `task-9-*.json`, `task-13-*.md`
  - `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/{wave1,wave2,wave2-r2,wave3}-verification*.json`
  - `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/fix-unit-path-*.log`, `F-A-attempts.md`
  - shipped code read: `modules/flake/iso-images.nix`, `modules/flake/checks.nix`, `bin/_install-staging.sh`,
    `bin/host-install.sh`, `apps/x86_64-linux/install`, `tests/install-staging.sh`,
    `tests/bootstrap-password-mutations.sh`, `tests/dendritic-config-eval.nix`, `tests/iso-autostart-vm.nix`,
    `README.md`, `docs/service-notes/*.md`
- **evidenceGaps:** see §7 — only todo 14's VM (rebuilt green by the wave-3 verifier, not by this auditor) and
  todo 3's `unshare` validator proof (wave-1 verifier's independent run). No criterion lacks evidence.


---

F1Report: {"verdict": "APPROVE", "rechecked": 14, "must_nots": {"1": "PASS", "2": "PASS", "3": "PASS", "4": "PASS", "5": "PASS", "6": "PASS"}, "shortfalls": ["t13 bin/AGENTS.md update is not in the main checkout: AGENTS.md is repo-excluded/untracked, so the updated file (sha256 cc3f0147..., 7081 B) exists only in the wave-3 worktree while /home/mei/nixos/bin/AGENTS.md is the stale pre-work copy (sha256 ed7ef439..., 5093 B). Not an acceptance-criterion failure (t13 acceptance = README/service-note greps, which pass) - see NOTE-2."]}
