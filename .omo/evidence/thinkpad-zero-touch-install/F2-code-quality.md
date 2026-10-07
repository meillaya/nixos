# F2 - Code quality review: `thinkpad-zero-touch-install`

- Reviewer: F2 code-quality (final verification wave). Read-only; nothing edited.
- Reviewed tip: `5d4052f` (`fix(iso): give the autoinstall unit a usable PATH`), landed on `main`.
- Read-only worktree inspected: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (git history inspected there).
- Plan: `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md` (read in full); brief `/home/mei/nixos/.omo/ulw-execute/briefs/F2-code-quality.md` (read in full).
- Skills consulted: `remove-ai-slops` (`/home/mei/node_modules/omo-ai/plugin/skills/remove-ai-slops/SKILL.md`) and `programming` (`.../programming/SKILL.md`); their overfit/slop criteria applied directly to the diff, tests, and production code below.

## verdict

**APPROVE (F2 scope).** No F2 blocker: every named shell file passes `bash -n`; the helper is sourced by exactly the two intended callers; no commit contains a secret, a stage dir, a `.direnv` path, or an unrelated file; the two documented commit deviations are acceptable. There are non-blocking majors/minors (below), and one **cross-cutting risk outside F2's REJECT gate** (the ISO fresh-boot abort, section 7) that F1/F4 must own.

---

## 1. `bash -n` on every changed shell file - PASS

Criterion (brief): "the new shell passes `bash -n`".

```
$ for f in bin/_install-staging.sh bin/host-install.sh apps/x86_64-linux/install \
            tests/install-staging.sh tests/bootstrap-password-mutations.sh; do bash -n "$f"; done
bash-n OK: bin/_install-staging.sh
bash-n OK: bin/host-install.sh
bash-n OK: apps/x86_64-linux/install
bash-n OK: tests/install-staging.sh
bash-n OK: tests/bootstrap-password-mutations.sh
```

(`bash -n` on the `.nix` files is expected to fail; they are not shell. The new helper also self-verifies syntax in its own QA harness: `task-3-*.log` "PASS C1 bash -n exits 0".)

Executed behavior spot-checks I ran myself:

- `bash tests/install-staging.sh` -> `install-staging=PASS`, rc=0.
- `bash tests/dendritic-apps.sh` -> `dendritic-apps=PASS`, rc=0.
- `bash apps/x86_64-linux/install --dry-run` -> rc=0; prints `transport: --extra-files <stage> --chown home/mei/.config 1000:100`; **no** `password for` line, no `$y$`.
- `bash bin/host-install.sh --dry-run --target-host 1.2.3.4 --host antagony --extra-files /tmp/x --chown home/mei/.config 1000:100` -> rc=0; prints the staging step and the forwarded transport, no secret.
- `bash bin/host-install.sh --dry-run --install-only --target-host 1.2.3.4` -> rc=0; prints `0-7. (skipped: --install-only)` and no operator staging step (correct skip).
- `bash bin/host-install.sh --chown /x` -> usage on stderr, rc=64 (parser arm).

`shellcheck`: not installed on this host (`command -v shellcheck` fails) -> N/A.

## 2. Dead code - FINDING (major)

Criterion (brief): "no dead code"; the brief explicitly names the five new helper functions and asks each to be used.

- `bin/_install-staging.sh:166-175` defines `staging_plan()`. **Nothing in the shipped tree calls it.**
  ```
  $ grep -rn 'staging_plan' bin apps tests modules
  bin/_install-staging.sh:166:staging_plan() {
  ```
  Its only other reference is the prose list in `bin/AGENTS.md:85`. Both real callers print their own plan text instead: the app's dry-run heredoc (`apps/x86_64-linux/install:218-240`) and the operator's `print_plan` (`bin/host-install.sh:198-216`).
- Why it is not a blocker per the brief: `staging_plan` is a pure `cat <<EOF`; it changes no runtime behavior, and the brief's REJECT rule is "dead/duplicated logic **that changes behavior**". Recorded as **major** because the plan's F2 scope names "no dead code" as a criterion and the function carries a second cost (see 5.1: it is the third copy of the plan prose).
- All other symbols check out. Function-usage scan over the five shell files reports `staging_plan` as the only definition with zero call sites; `staging_init`/`staging_password`/`staging_artifacts`/`staging_identity` are each called from `bin/host-install.sh` and/or `apps/x86_64-linux/install`.
  ```
  $ bash -c 'for f in <the five files>; do grep -oE "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" "$f" | sed "s/()//" | sort -u | while read fn; do
      n=$(grep -cE "(^|[^A-Za-z0-9_])${fn}([^A-Za-z0-9_]|$)" "$f"); [ "$n" -le 1 ] && echo "$f POSSIBLY-UNUSED $fn"; done; done'
  bin/_install-staging.sh POSSIBLY-UNUSED staging_plan
  ```
  No unused leftovers in the app or `bin/host-install.sh` diffs (`ensure_mkpasswd`, `announce_unfolded_key`, `rescue_disk_by_id`, `identity_staged`, `operator_chown_*` are all reachable).

## 3. Caller discipline - PASS

Criterion (brief): the helper is sourced by exactly the intended caller(s); no third source, no duplicated staging logic, no copy-paste of internals.

```
$ grep -rn '_install-staging.sh' bin apps tests
bin/host-install.sh:141:  . "$root/bin/_install-staging.sh"          # guarded by: if [[ "$install_only" != true ]]
apps/x86_64-linux/install:164:source "$flake_root/bin/_install-staging.sh"
tests/install-staging.sh:19:helper=bin/_install-staging.sh            # variable for grep, not a source
```

- Exactly the two intended callers source it, and `bin/host-install.sh` sources it only on the operator entry point (`bin/host-install.sh:136-142`), so the `--install-only` path the app drives never re-stages. No other file sources it.
- No duplicated staging internals: neither caller re-implements `mktemp`/`install -d`/`mkpasswd`/regex validation; both call the helper.
- The app forwards `--chown` only when `staging_identity` actually staged the subtree (`apps/x86_64-linux/install:629-633`, `identity_staged` set at `:424-441`); the operator mirrors that with `--stage-identity` (`bin/host-install.sh:186-192`). Both hand the ownership path to `nixos-anywhere`; neither chowns anything itself.

## 4. Commit strategy - assessment (incl. the two documented deviations)

Range reviewed: `5a33373..5d4052f` (18 commits).

- **One commit per todo / conventional messages / wave order:** holds. Wave 1 (4,5,3,12,1,2) all precede wave 2 (6,15,7,8,9), which precedes wave 3 (11,13,10,14). Messages are `feat|fix|test|docs(install|iso)` scoped. Each commit's file set is single-purpose:
  ```
  $ git show --stat --format='' <c>   # per commit; every commit touches only its todo's files
  ```
- **No secrets / stage dirs / `.direnv` paths / unrelated files:**
  ```
  $ git diff 6992dd2..5d4052f | grep -nEi 'BEGIN (OPENSSH|RSA|EC|PGP) PRIVATE KEY|AGE-SECRET-KEY|-----BEGIN'   # -> no matches
  $ git diff --name-status --diff-filter=A 6992dd2..5d4052f
  A bin/_install-staging.sh
  A tests/bootstrap-password-mutations.sh
  A tests/install-staging.sh
  A tests/iso-autostart-vm.nix
  ```
  No commit touches `config/hosts/intake/*` (pipeline output), `secrets/*`, `flake.lock`, or `.direnv`. The one `.direnv` occurrence is an *exclusion* inside `tests/bootstrap-password-mutations.sh` (`tar --exclude=./.direnv`), not a committed path.
- **Deviation (a) - todo 12 landed as `bde4937` + `b210a75`:** **acceptable.** `bde4937` adds the mutation script + the `checks.nix` wiring; `b210a75` (7 lines) fixes a genuine sandbox defect (a writable `HOME` for nix's chroot store) without which the check cannot run under `runCommand`. Same todo, same artifact, no behavior drift; the fixup is documented and was re-verified (`wave1-verification.json` t12: "7 controls PASS, 6 mutants KILLED").
- **Deviation (b) - `bf90e20` verify-fix, and the wave-3 rebase dropping a force-added `bin/AGENTS.md`:** **acceptable.**
  - `bf90e20` is a root-cause fix for a real defect the wave-2 verifier found (`wave2-verification.json` t6/t7 `needs-fix` -> `wave2-verification-r2.json` t6/t7 `confirmed`): `nixos-anywhere` runs `chown -R` after disko has already wiped the disk, so forwarding `--chown` for a subtree that was never staged would abort an install on a wiped machine. It touches only `apps/x86_64-linux/install` and is exactly the "wave-2 verify-fix" the brief names.
  - The dropped `bin/AGENTS.md`: the old docs commit `ae0a3ef` did force-add it (`git show --name-only ae0a3ef` lists `bin/AGENTS.md`); `0cc6c55` does not. This is the *correct* outcome, not a loss: every `AGENTS.md` in this repo is excluded by `git/info/exclude` (`git check-ignore -v bin/AGENTS.md` -> `/home/mei/nixos/.git/info/exclude:12:AGENTS.md`; all 8 `AGENTS.md` files show as `!!` ignored). The updated content is byte-identical to the dropped commit and present in both the landed checkout and the worktree (`git show ae0a3ef:bin/AGENTS.md | diff - bin/AGENTS.md` -> identical). Force-adding one of them was the anomaly. Minor: it is therefore untracked, so a fresh clone will not carry it (see 5.6).
- **Undocumented third fixup - `5d4052f` (HEAD):** the brief names "the two known deviations" but there is a third extra commit at the tip, `fix(iso): give the autoinstall unit a usable PATH` (touches `modules/flake/iso-images.nix` + `tests/iso-autostart-vm.nix`). It fixes the unit's service `PATH` (the wrapper's `#!/usr/bin/env bash` could not resolve -> status 127) and tightens the VM assertions so they fail on exactly that regression. Atomic, single-concern, no forbidden content -> acceptable, but the brief undercounts: review the fixups as a set, not as two.
- **Minor - "the docs commit comes last" is violated:** the plan's commit strategy says the docs commit comes last; `0cc6c55` (docs) is followed by `19e2e11` (t10), `a1c86ad` (t14) and `5d4052f`.

## 5. Nix quality and general quality smells

### 5.1 Plan-text triplication - minor (duplication)
The staging plan prose now exists in three places: `bin/_install-staging.sh:166-175` (`staging_plan`, unused), `apps/x86_64-linux/install:218-240` (heredoc), `bin/host-install.sh:198-216` (`print_plan`). The helper exposes `staging_plan` precisely to be that single source; leaving it uncalled both wastes it and leaves three texts to keep in sync.

### 5.2 Transport construction duplicated - minor (duplication)
`bin/host-install.sh` builds the same `--extra-files`/`--chown` argument vector twice, once as a display string and once as an array: `print_plan` at `:200-211` and `stage_install` at `:333-344`. They agree today; drift between them would silently make the printed plan lie about the executed command.

### 5.3 Oversized scripts - major (maintainability; `remove-ai-slops` cat. 10 / `programming` Smell 1)
Measured with the skill's own command (`awk '!/^[[:space:]]*$/ && !/^[[:space:]]*(\/\/|#)/' <file> | wc -l`):
```
bin/_install-staging.sh             pure_LOC=126
bin/host-install.sh                 pure_LOC=318   <-- over the 250 ceiling
apps/x86_64-linux/install           pure_LOC=539   <-- over the 250 ceiling (this wave added ~313 lines)
tests/install-staging.sh            pure_LOC=57
tests/bootstrap-password-mutations.sh pure_LOC=100
modules/flake/iso-images.nix        pure_LOC=89
tests/iso-autostart-vm.nix          pure_LOC=69
```
`apps/x86_64-linux/install` now owns arg parsing *and* DMI detection *and* worktree prep *and* enroll *and* identity resolution *and* staging *and* the btrfs rescue *and* the host/disk match *and* the install phase *and* the dry-run plan - "if the answer needs 'and', the file needs splitting". Not a behavior bug and not one of the brief's REJECT triggers; flagged because the wave pushed an already-large script further past the ceiling with no `SIZE_OK` acknowledgement. Suggest splitting the rescue + host-match concerns out, or recording an explicit, justified opt-out.

### 5.4 `bin/_install-staging.sh` self-checks - nit
`staging_password` writes the hash then re-`stat`s it (`:92-107`) and `staging_artifacts` re-`stat`s the directory it just created (`:130-131`). `programming` Smell 3 ("redundant verification after a write") applies in principle, but here the mode/ownership bits are part of the security contract the plan deliberately made explicit, and the plan required the self-check, so this is plan-mandated and load-bearing -> keep.

### 5.5 `iso-images.nix` / `checks.nix` review - PASS (no new smells)
- `modules/flake/iso-images.nix:83-115` (`nixos-autoinstall`): one definition, unit name used consistently; `unitConfig` fields match the plan and the eval wall; **no `|| true`** in the unit (`git grep -n '|| true' modules/flake/iso-images.nix` -> nothing); `lib.mkForce true` at `:137` is the pre-existing, correct initrd re-enable for pending hosts, not new misuse; `lib.genAttrs isoHosts isoConfigFor` at `:141-142` builds `flake.iso` from `flake.isoConfig`, so the wall and the VM boot the same config the image builds from.
- `${inputs.self}` (`:78`) and `config.flake.apps.x86_64-linux.install.program` (`:106`) are intentional store references (bake the flake; run the shipped app), not accidental hardcoded paths.
- `modules/flake/checks.nix:42-52` wires `install-staging` in the established `runCommand` shape; `:60-67` wires `bootstrap-password-mutations`; `:110-119` gates `iso-autostart-vm` on `system == "x86_64-linux"` (correct: ISO hosts are x86_64-linux only). `dendritic-config-eval` keeps its `assert ... == "PASS"` form.
- Minor (pre-existing pattern): `isoHosts = [ "remembrance" "antagony" ]` hardcodes the host list rather than deriving it from `nixosConfigurations`.

### 5.6 Docs: updated but untracked - minor
`bin/AGENTS.md` carries the new flags (`--extra-files`, `--chown`, `--stage-identity`, `--stage-identity ignored with --install-only`) and is correct, but is untracked by repo convention (see 4). Plan todo 13 asked for it; the acceptance criteria for todo 13 (`grep --extra-files README.md docs/service-notes/*.md`, `grep 'nixos.autoinstall=1' docs/service-notes/nixos-anywhere-iso-install.md`) are met, and the content exists on disk. Consequence only: a fresh clone lacks it.

### 5.7 Docs prose vs observed behavior - minor
README (`:150-160`) and `docs/service-notes/nixos-anywhere-iso-install.md` (`:127-140`) describe the ISO boot as inert-but-usable ("append `nixos.autoinstall=1` at the boot menu", "the install unit never activates"). The same config, booted fresh, aborts before switch-root (section 7). "Never touches a disk" is literally true, but the prose implies a bootable medium. See 7.

## 6. Overfit / slop pass (`remove-ai-slops` + `programming`), applied directly

No separate upstream code-review artifact was supplied for this plan, so there is no upstream skill-perspective coverage claim to confirm; the check below is performed by me on the diff, tests, and production code.

- **Obvious comments:** none to remove. The new comments explain WHY (tmpfs requirement, why `--chown` only when staged, why the sentinel exists, why the stage must not be chowned). KEEP per the skill.
- **Over-defensive:** only the plan-mandated mode self-checks (5.4). `_staging_die` returning 1 instead of exiting is deliberate and documented (lets callers decide). No boundary-validation deletion candidate.
- **Excessive complexity / needless abstraction:** none beyond `staging_plan` (2) and the single-call-site `announce_unfolded_key` (`apps/x86_64-linux/install:618-620`, one `printf`) - harmless.
- **Dead code:** `staging_plan` (2).
- **Duplication:** plan prose x3 (5.1), transport vector x2 (5.2).
- **Performance:** N/A (shell).
- **Tests that cannot fail for a regression / implementation mirroring - minor (plan-mandated):** `tests/install-staging.sh:36-60` is almost entirely literal token greps against source text (`'--method=yescrypt'`, `'_STAGING_HASH_REGEX='`, `'unset pw'`, `'0700'`, `'transport+=(--extra-files "$stage")'`, `'--chown "home/${install_user}/.config"'`, and a `printf`-format count). These can only fail on a text edit, not on a behavioral regression, and they pin implementation detail. They are exactly what plan todo 10 asked for, so this is not scope drift - but the genuine behavioral value of the file is its last block (`:64-88`): a live `--dry-run` run asserting no `password for` line and no `$y$` hash.
- **Tautological assertion - nit:** `tests/dendritic-config-eval.nix:295` `assert hasInfix "install" isoAutoinstallUnit.script;` matches the literal path `.../install` embedded in the script; it can only fail if the whole program reference disappears. Plan-mandated ("the script containing `install`").
- **Missing test (behavioral coverage) - major:** no committed test executes `staging_password`/`staging_artifacts`/`staging_identity` and asserts the resulting modes/regex/layout. The invariant is covered only by source greps (6 above); the runtime proof lives in the todo-3 QA harness (`task-3-*.log`, 29/29 PASS incl. `unshare` validator proof), which is not part of the shipped `checks`. So `nix flake check` can stay green while the generator is behaviorally broken. The plan deliberately routed the decisive proof to the manual/deliberate gate (IS-1 evidence names "the deliberate validator proof"), so this is a false-confidence risk to flag, not a plan violation. Recommendation: promote the todo-3 harness to a `checks` entry (it uses only `bash`/`coreutils`/`grep`/`mkpasswd` and `unshare`).
- **Test discipline (nondeterminism):** `tests/iso-autostart-vm.nix` uses state/event assertions (`systemctl show -p ActiveState|ConditionResult|Result`, `wait_for_unit`, `wait_until_succeeds`) - no fixed sleeps. `tests/install-staging.sh` and `tests/dendritic-apps.sh` are deterministic (I ran both; `wave3-verification.json` reports each twice with identical output). Good.

## 7. Cross-cutting risk OUTSIDE the F2 REJECT gate - escalate to F1/F4

**A fresh boot of the shipped ISO config aborts in initrd activation (kernel panic), so the real installer medium very likely does not boot.** This is not a blocker for F2 (it is not a `bash -n` failure, not dead code, not a commit problem, and `modules/nixos/bootstrap-password.nix` is untouched by this wave), but it undermines the plan's headline outcome ("the installer stick" installs a loggable machine) and must be owned by F1 (Must-NOT/plan compliance) and F4 (IS fidelity).

Evidence (all existing artifacts):

- `modules/nixos/bootstrap-password.nix:46,58` (`has_unlocked_password || fail "missing $hash_file"`) - the activation script fails a fresh machine with no `/var/lib/nixos-bootstrap/mei-password.hash`; the git history for this file over `5a33373..5d4052f` is empty (pre-existing defect, unchanged by this wave).
- `.omo/evidence/thinkpad-zero-touch-install/task-14-thinkpad-zero-touch-install.log:2385-2396`:
  ```
  The initrd activation aborts at the bootstrapPasswordHash validator (missing ...)
    [ 4.04] initrd-nixos-activation-start[209]: bootstrap password hash validation failed: missing /var/lib/nixos-bootstrap/mei-password.hash
    [ 4.07] Failed to switch root: ... 'os-release file is missing.'
    [ 4.36] Kernel panic - not syncing: sysrq triggered crash
  ... so the same fresh-boot activation abort applies to the real ISO config; recorded
  ```
- `tests/iso-autostart-vm.nix:1-30,60-92` - the shipped VM test can only boot the ISO config by **injecting a test-only hash fixture** (`seed-bootstrap-password`), i.e. the config as shipped is not bootable fresh; the fixture exists only inside the test.
- `.omo/evidence/thinkpad-zero-touch-install/F-A-attempts.md` - three attempts to build/boot the real ISO; verdict `UNVERIFIABLE-DISK` (needs ~21 GiB; `xorriso` short by ~1.1 GiB). The real-medium boot is **unverified**, and the mechanism evidence stands.

What is *proven* about the gate itself: the eval wall (`tests/dendritic-config-eval.nix:273-296`, incl. the negative `kernelParams` assertion) and the VM (seeded) show the unit is opt-in, inert by default, and fails into the rescue target; the VM was falsified both by removing the condition and by reverting the PATH fix (`wave3-verification.json` t11/t14). What is *not* proven: that the shipped ISO reaches the boot menu, let alone the gate.

## checked artifact paths

- Plan: `.omo/plans/thinkpad-zero-touch-install.md`; brief: `.omo/ulw-execute/briefs/F2-code-quality.md`.
- Code: `bin/_install-staging.sh`, `bin/host-install.sh`, `bin/AGENTS.md`, `apps/x86_64-linux/install`, `modules/flake/apps.nix`, `modules/flake/iso-images.nix`, `modules/flake/checks.nix`, `modules/nixos/bootstrap-password.nix` (read-only).
- Tests: `tests/install-staging.sh`, `tests/bootstrap-password-mutations.sh`, `tests/iso-autostart-vm.nix`, `tests/dendritic-apps.sh`, `tests/dendritic-config-eval.nix`; `.omo/evidence/thinkpad-zero-touch-install/task-{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}-*`, `wave1-verification.json`, `wave2-verification.json`, `wave2-verification-r2.json`, `wave3-verification.json`, `F-A-attempts.md`, `fix-unit-path-*.log`.
- Git: commits `5a33373..5d4052f` (18), stats/diffs/`git grep`/`git check-ignore`/`git ls-files` in the read-only worktree; reflog commits `ae0a3ef`, `a25219f`.
- Docs: `README.md`, `docs/service-notes/nixos-anywhere-iso-install.md`, `docs/service-notes/new-machine-ssh-install.md`.

## evidence gaps

1. I did **not** build `.#iso.antagony` or run `.#checks.x86_64-linux.iso-autostart-vm` (cold closure ~10 min; ISO needs ~21 GiB and has repeatedly failed with `xorriso: image > free space`). Sections 5.7/7 rest on the recorded `task-14` log, `wave3-verification.json`, and `F-A-attempts.md`, not on my own run.
2. I did **not** re-run `tests/bootstrap-password-mutations.sh` (needs `jq` + a flake eval); I verified its wiring in `checks.nix:60-67` and its recorded PASS (`wave1-verification.json` t12).
3. `shellcheck` is not installed -> shell lint gate N/A.
4. `nix flake check --all-systems --no-build` was not run here (F3's scope).
5. The plan lists "two known deviations"; I found a third fixup commit (`5d4052f`) not covered by the brief (section 4).

---

## Gate-review fields

- **recommendation:** APPROVE (F2 scope).
- **blockers:** none. Each candidate was tested against a stated criterion and did not qualify:
  - `staging_plan` unused -> criterion "no dead code" is stated, but the brief's own REJECT rule requires dead logic "that changes behavior"; a pure `cat` does not. Recorded as major.
  - oversized scripts -> not a stated criterion; recorded as major.
  - ISO fresh-boot abort -> no plan criterion names "the ISO boots"; `IS-4` ("touches nothing") holds literally, and the defect is pre-existing. Recorded as a cross-cutting escalation (section 7), not an F2 blocker.
- **originalIntent:** give the ThinkPad installer one run that ends with a loggable machine whose enrollment record and age identity live inside it (no second USB), plus an optional per-boot opt-in auto-install on the installer ISO, with tests/docs proving it.
- **desiredOutcome:** `nix run .#install` / `bin/host-install.sh` mint and stage a validator-conforming `mei` password, persist the enrollment artifacts + age identity into the target, and refuse unsafe installs; a plain ISO boot stays inert; the tests and docs cover all of it.
- **userOutcomeReview:** the shell/Nix code that carries that outcome is present, coherent, and passes `bash -n`; caller discipline is correct; the password hash path is proven against the real validator (`task-3` C8, `unshare`, rc=0). Three caveats the user should see: (1) the helper's runtime behavior is only greped by `nix flake check` (6), (2) `staging_plan` never runs (2), (3) **the installer medium itself is very likely unbootable as configured** (7) - so the "install by itself" outcome is, on today's evidence, not reachable on a real stick, and the ISO boot must be resolved or explicitly accepted by the user.
- **userOutcomeReview - deviations:** commit deviations (a) and (b) are acceptable as argued, and the dropped `bin/AGENTS.md` is consistent with the repo's repo-wide `AGENTS.md` exclusion.
