# Gate review (independent reviewer) - ulw-loop plan 01a1169d

Reviewer: gate-review child `st_01a116e8` (category deep-low), spawned because the plan's
checkpoint schema rejects a self-review. Reviewed at 2026-10-07 ~15:10-15:20 local.
Scope reviewed: the frozen gate bundle `G012-.../a0/` (cli-transcript.txt, data-diff.txt),
the three delivered trees (`/home/mei/nixos/tools/zix`, `/home/mei/machine0`,
`/home/mei/railway-nix-agent`) and the research artifacts
(`/home/mei/nixos/.omo/ulw-research/20261007-100807/`).

## Verdict: BLOCK

Two blockers (B1, B2) and three note-level defects. One blocker is a delivered artifact
that states a number no log contains and that contradicts the same file's own prose; the
other is criterion-cited evidence that records the opposite of the claim it is cited for.
Every load-bearing deliverable claim I could execute myself PASSED - the defects are in
the proof artifacts, not (with the one doc exception below) in the shipped behavior.

## What I verified by execution (my runs, not the run's logs)

| # | command | result |
|---|---|---|
| V1 | `cd /home/mei/nixos && bash tests/zix.sh` | EXIT 0; `Ran 26 tests ... OK`; `zix-check=PASS` |
| V2 | empty `mktemp -d` cwd + `python3 /home/mei/nixos/tools/zix/cli.py get hello@2.10 --profile <dir>/profile` | `ok: got hello@2.10`; `<dir>/profile/bin/hello` -> `Hello, world!`; rerun -> `already installed`; host has **no** `/etc/zix`, so this is genuinely repo-less |
| V3 | `cd /home/mei/machine0 && nix flake check --no-build` | EXIT 0 (checks.x86_64-linux.coding-eval, nixosModules.*, packages.* evaluated; only `lib` reported unchecked) |
| V4 | `cd /home/mei/machine0 && nix build .#zix --no-link --print-out-paths` | EXIT 0 -> `/nix/store/izi2081lv34fn45crl9bm29kcaz3kazh-zix-0.2.0` |
| V5 | `cd /home/mei/railway-nix-agent && bash scripts/validate.sh railway-nix-agent:omo ulw-gate-check 28081` | **15 PASS / 0 FAIL**, exit 0: 401 on `/`, `/token`, wrong pw, empty pw, forged loopback `Host`; `/healthz` 200 unauthenticated; authenticated 200; published port listening; agent 7681 loopback-only; `zix get ripgrep` 6 s, `hello@2.10` 2 s (ran `hello (GNU Hello) 2.10`), `jq` 2 s, `--list` and idempotence 0 |
| V6 | `cat .omo/ulw-research/.../evidence/ulw-railway-compressed.txt` | exactly `413365638` (10 bytes) - matches the 394 MiB gzip claim |
| V7 | provenance | `evidence/ulw-railway-build6.log` tags `f07f11175e40`; `podman images` shows `localhost/railway-nix-agent:omo` = `f07f11175e40` - V5 ran against the documented artifact |
| V8 | `evidence/ulw-omo-build.out`, machine0 `git status`, `tools/zix` vs mirrors | omo log carries `omo-5.1.22` + `OMO_BUILD_EXIT=0`; machine0 staged state matches `data-diff.txt`; mirrors differ (see N1) |

## Blockers

### B1 - `report.html` prints an unsupported container-peak number (3 places) and contradicts itself
- Artifact: `/home/mei/nixos/.omo/ulw-research/20261007-100807/report.html` lines **139**
  (figure label `308`), **148** (`308 MB container peak`), **160** (`512 MB fits fast-path
  installs (308 MiB peak)`). The same file states 303 MiB at lines **82** and **180**;
  `probe-run.html` lines 82/138/147/159 repeat the 308.
- The only measurement in the bundle is `evidence/ulw-railway-validate4.log:26`
  `memory.peak: 317771776 bytes` = **303.0 MiB**; `evidence/ulw-railway-validate3.log:26`
  records `342044672 bytes` = 326 MiB. `SYNTHESIS.md:179` and
  `railway-nix-agent/README.md:48` both use 303 MiB. **No file anywhere contains 308**
  (grepped the session dir, `/tmp`, and `$HOME` logs).
- This falsifies the claim under review, "every number in SYNTHESIS/report traces to the
  logs" (research brief SC6: "every claim cited"), and it is an internal contradiction in a
  delivered artifact.
- Compounding: the number is a single-sample value. My independent V5 re-run measured
  `memory.peak: 417734656 bytes` = **398 MiB** on the same image and command, so the
  figure/table should carry the sample basis (or a range), and the "512 MB fits" line
  should not rest on one run.
- Fix: replace 308 with the cited measurement (303 MiB, source `validate4.log:26`) - or
  drop the two numbers from the figure/table - and state that the peak is run-dependent.

### B2 - the frozen transcript and G001/C001 cite a `zix-0.1.0` build for the `zix-0.2.0` claim
- `G012-.../a0/cli-transcript.txt` heading "=== machine0 zix build (final) ===" records
  `building '/nix/store/...-zix-0.1.0.drv'` and `/nix/store/ab7g67...-zix-0.1.0`;
  `evidence/ulw-m0-zix-build2.out` likewise contains `zix-0.1.0` three times. Yet
  `goals.json` G001/C001 `capturedEvidence` says "nix build .#zix -> zix-0.2.0" and names
  that same log as its proof.
- The claim itself is TRUE - my V4 rebuild yields `/nix/store/izi2081...-zix-0.2.0`, exit 0 -
  but the evidence the criterion is bound to records the opposite, and "(final)" is wrong:
  the log predates the `pkgs/zix` version fix. A gate bundle whose purpose is to prove the
  claims must not cite a log that contradicts them.
- Fix: re-capture the machine0 `nix build .#zix` transcript into the bundle (or annotate
  that `ulw-m0-zix-build2.out` is pre-fix), and re-point G001/C001's evidence at it.

## Notes (not criterion-cited; fix opportunistically)

- **N1 - the "mirror synced, diff clean" claim is false as of review time.** `diff -rq` shows
  `tools/zix/README.md` differs from both `/home/mei/machine0/tools/zix/README.md` and
  `/home/mei/railway-nix-agent/vendor/zix/README.md`: the four-line caveat at
  `tools/zix/README.md:169-172` ("`get NAME` (no version) resolves the newest version with a
  *prebuilt store path* ... vscode served 1.104.3 while 1.107.x existed ... Pin
  `NAME@VERSION`") is missing from both vendored copies. Doc-only, but the known-limitation
  paragraph is exactly what the instrumentation credits itself with recording.
- **N2 - test-count wording drifts.** `journal.md` says "Tests: 23 -> 25"; the shipped suite
  is 26 (V1), which `SYNTHESIS.md` and the self-review state correctly.
- **N3 - `git` staging:** both repos are staged-only with no commits, as the self-review
  states; the machine0 tree I evaluated is the staged tree. Working trees carry no unstaged
  drift beyond the run's own files.
- **N4 - leftover container state belongs to a different, still-live task, not this run.**
  During review, `podman ps` showed `ulw-a7-tokenprobe` running and `ulw-a7-m0-agent:v1`
  (1.37 GB) plus an untagged 2.67 GB image, all created minutes before the review. These are
  not this run's leftovers (its own teardown list is otherwise accurate); flagging so nobody
  misreads them as an uncleaned gate residue. I did not touch them.
- **N5 - `/tmp/ulw-a7/npmtest`** (root-owned, a dead worker's build) still needs `sudo rm -rf`,
  as the run itself records.

## Cleanup receipt (reviewer's own QA resources)

- `podman rm -f ulw-gate-check` -> removed; `podman ps -a` afterwards lists only
  `ulw-a7-tokenprobe` (N4, not mine).
- removed `/tmp/gate-validate.log`, `/tmp/gate-zix-check.sh`, `/tmp/gate-zix.*`,
  `/tmp/ulw-railway-vol`, `/tmp/ulw-railway-get-{rg,hello,jq}.log`; verified
  `ls -d /tmp/gate-* /tmp/ulw-railway*` returns nothing.
- No repository file was modified; this review file is the only file I wrote.

## Delivery note

`task_send({ to: 'lead' })` is not addressable from this reviewer child (the host answered
`No task found for "lead"`, `known_tasks: []`), and the ulw-loop SDK is bound to its own
session (`ULW_LOOP_PLAN_MISSING ... The SDK is bound to the current session; resume the
owning session to target its plan`). The verdict therefore travels back through this
child's task result, which the host delivers to the lead automatically. The lead should
checkpoint G012 with `by = "category:deep-low"` and this verdict (BLOCK) attached, and
close it only after B1/B2 are fixed and re-reviewed.

## Recommendation

Fix B1 and B2 (both are text/evidence edits inside the run's own artifacts, no code change),
then re-run the gate. Nothing I executed contradicts the three deliverables: zix 0.2.0 with
a working repo-less `get`, the machine0 integration evaluating clean, the omo 5.1.22 build,
and the Railway image's auth gate / loopback binding / runtime installs reproduced 15/0 on
the kept image.
