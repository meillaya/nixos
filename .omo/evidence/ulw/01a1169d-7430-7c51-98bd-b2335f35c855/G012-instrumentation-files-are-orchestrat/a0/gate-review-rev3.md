# Gate review rev3 (final delta re-review, protocol cap) - ulw-loop plan 01a1169d

Reviewer: round-3 delta re-review child `st_01a116fe` (category deep-low), spawned by the lead after
the round-2 BLOCK. Reviewed 2026-10-07 11:32 - 11:35 EDT (15:32Z - 15:35Z).
Scope: **only the three round-2 blocker fixes** - NB1 (frozen bundle transcript), N6 (stale staged
index), NB2 (journal correction). Explicitly out of scope and NOT re-executed: any deliverable
validation, everything round 1 already executed green (validate.sh 15/15, repo-less `zix get`, unit
suites, flake check), and the round-2 approvals (B1, item 3, item 5).

## Verdict: APPROVE

All three fixes are resolved on the evidence I read and ran myself. No new blockers. The sibling
session's containers/images/`run.sh` were not touched by this review, and the journal now records
the NB2 correction the round-2 reviewer asked for.

## What I ran (my runs, not the run's logs)

| # | command | observed |
|---|---|---|
| V1 | `ls -la .../G012-.../a0/` | `cli-transcript.txt` 5205 B, mtime **11:32** (rebuilt after round 2 at 11:31) |
| V2 | `cat .../a0/cli-transcript.txt` | section 1 heading `=== machine0 zix build + flake check (fresh capture, 11:21) ===` |
| V3 | `grep -c 'zix-0.1.0'` / `grep -c 'zix-0.2.0'` on the transcript | `0` / `3` |
| V4 | `grep -n 'zix-0\.1\.0\|zix-0\.2\.0\|FINAL_ZIXBUILD_EXIT\|fresh capture'` | only lines 1, 4-7: heading + `zix-0.2.0.drv` + `zix-0.2.0` + `FINAL_ZIXBUILD_EXIT=0` |
| V5 | `find ... -name 'ulw-m0-zix-build-pre-fix.out'` + `cat` | present at `.../ulw-research/20261007-100807/evidence/ulw-m0-zix-build-pre-fix.out`, 15046 B, mtime 11:21, `zix-0.1.0` x3 + `ZIX_BUILD2_EXIT=0` |
| V6 | `cd /home/mei/railway-nix-agent && git status --short \| grep -c '^AM'` | **0** |
| V7 | `cd /home/mei/machine0 && git status --short \| grep -c '^AM'` | **0** |
| V8 | per-file `git ls-files -s` (index blob) vs `git hash-object` (worktree blob), both repos | equal for every checked file (below) |
| V9 | `git diff -- README.md vendor/zix/README.md` (railway) / `README.md tools/zix/README.md zix.json` (machine0) | **0 lines** in both |
| V10 | `grep -n 'SIBLING SESSION' journal.md`; `sed -n '95,125p'` | hits at `:104` and `:111`; correction block read in full |

Blob equality (V8), index == worktree:

- railway-nix-agent: `README.md` `2a5447df…` == `2a5447df…`; `vendor/zix/README.md` `e1fb4e99…` == `e1fb4e99…`
- machine0: `README.md` `72135102…` == `72135102…`; `tools/zix/README.md` `e1fb4e99…` == `e1fb4e99…`; `zix.json` `9dcfaf77…` == `9dcfaf77…`

The `vendor/zix/README.md` index hash is now `e1fb4e99…` - the same value machine0's index holds and
the value round 2 reported as the worktree copy that the stale railway index (`a6cadba`) lacked. The
stale index is gone.

## Fix-by-fix

1. **NB1 - cli-transcript.txt rebuilt with the fresh 0.2.0 capture - RESOLVED.**
   The bundle file (`a0/cli-transcript.txt`, mtime 11:32) now opens with
   `=== machine0 zix build + flake check (fresh capture, 11:21) ===` and records
   `/nix/store/178k0k0k7hjppdwf24icpxdsyxxbnpdl-zix-0.2.0` with `FINAL_ZIXBUILD_EXIT=0` (V2-V4);
   `grep -c 'zix-0.1.0'` is **0**, so there is no un-annotated (or any) 0.1.0 build line left in the
   frozen bundle. The pre-fix capture still exists, unchanged, only at
   `evidence/ulw-m0-zix-build-pre-fix.out` (15046 B, `zix-0.1.0` x3, `ZIX_BUILD2_EXIT=0`, V5) - the
   0.2.0 store path also equals the one round 2's own `nix build .#zix` produced.

2. **N6 - staged blobs match the worktree in both repos - RESOLVED.**
   `grep -c '^AM'` is 0 in `railway-nix-agent` (V6) and 0 in `machine0` (V7); `git diff` over the
   README files is empty in both (V9); and the index blob hash equals the worktree blob hash for
   `README.md` + `vendor/zix/README.md` in railway and for `README.md` + `tools/zix/README.md` +
   `zix.json` in machine0 (V8). Round 2's stale railway index (`AM README.md`, `AM
   vendor/zix/README.md`, blob `a6cadba`) is corrected.

3. **NB2 correction - journal records the sibling session and stands down - RESOLVED.**
   `journal.md:111-117` records that the ulw-a7 containers, images (v5/v6 + 2.67 GB untagged layer)
   and the live `/home/mei/.cache/m0railway-a7/qa/run.sh` belong to a **SIBLING SESSION (PI_SESSION_ID
   01a116c0-...)**, not this run's closed worker; that both sessions independently used the `ulw-a7`
   scratch name, which is why the run read the artifacts as its own and killed `run.sh` + canary
   processes and removed some images ("I killed ... before the reviewer caught it") - the overreach
   from the scratch-namespace collision; that the artifacts "are left alone from here"; and that "no
   container/image cleanup for the a7 family is attempted by this run". That is exactly the round-2
   fix: an accurate state claim in place of the false kill/removal claim, no second cleanup attempt.

## Notes (not criterion-cited)

- The journal's old `N5` line at `:95` ("`/tmp/ulw-a7/npmtest` needs sudo") still reads as originally
  written; the N7 correction below it (`:102-103`, `/tmp/ulw-a7` gone with the scratch, the N5 note
  no longer applies) supersedes it. Round 2 flagged N7 as a note; it is not one of my three items and
  is recorded, not blocking.
- The a7 sibling lane's activity does not touch the reviewed trees: no file under `machine0` or
  `railway-nix-agent` is modified beyond the staged fix deltas (V6-V9).

## Cleanup receipt (reviewer's own QA resources)

- Spawned nothing: no server, no container, no image build, no tmux, no browser, no monitor, no
  background cell, no temp file or dir.
- Only read-only commands: `ls`, `cat`, `grep`, `find`, `sed`, `wc`, `stat`, `date`, `git status`,
  `git diff`, `git ls-files -s`, `git hash-object`. The `git` reads refresh `.git/index` stat caches;
  no tracked content changed - both repos still show zero unstaged diff (V9).
- Did not touch the live sibling session's containers, images, processes or drafts (per the NB2
  instruction and round 1's N4 guidance).
- The only write was the review file itself: this `gate-review-rev3.md`.

## Delivery note

The verdict travels back through this child's task result, which the host delivers to the lead. The
lead may checkpoint G012 with verdict **APPROVE** and `by = "category:deep-low"`; this is the
protocol's final re-review (round 3, cap reached).
