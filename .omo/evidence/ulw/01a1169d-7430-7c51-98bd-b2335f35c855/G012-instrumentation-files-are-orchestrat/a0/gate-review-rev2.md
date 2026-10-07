# Gate review rev2 (delta re-review) - ulw-loop plan 01a1169d

Reviewer: delta re-review child `st_01a116f7` (category deep-low), spawned by the lead after the
round-1 BLOCK. Reviewed 2026-10-07 11:24:48 - 11:31 local (15:24:48Z - 15:31Z).
Scope: **the five deltas the lead listed**, plus the two original blockers. Explicitly out of
scope (round 1 already executed them green): the Railway image validation, the repo-less
`zix get` proof, the unit suites.

## Verdict: BLOCK

B1 is fully resolved. B2 is **half** resolved: the log the criterion cites is now correct, but
the frozen bundle's own transcript - the other artifact B2 named - still records the pre-fix
`zix-0.1.0` build under a "(final)" heading. Two new blockers: that transcript (NB1), and
delta item 4, whose cleanup claim is false as of this review - the "dead" worker's harness is
a **live** sibling session that has already reintroduced the images (NB2).

## What I ran (my runs, not the run's logs)

| # | command | observed |
|---|---|---|
| D1 | `grep -c 308 report.html` / `probe-run.html` | `0` both (exit 1) |
| D2 | `grep -rn "308" $SDIR . READMEs` | only unrelated hits: dsh port `3080`, file mode `308`, hash substrings |
| D3 | `grep -n "303\|398\|512" report.html` | 82, 140, 149-150, 161, 181 (see below) |
| D4 | `grep -c "zix-0.1.0\|zix-0.2.0" evidence/ulw-m0-zix-build2.out` | `0` / `3`; `FINAL_ZIXBUILD_EXIT=0`; 3187 B, mtime 11:21 |
| D5 | `wc -c evidence/ulw-m0-zix-build-pre-fix.out`; grep | 15046 B, `zix-0.1.0` x3, `ZIX_BUILD2_EXIT=0`; mtime 11:21 |
| D6 | `cd /home/mei/machine0 && nix build .#zix --no-link --print-out-paths` | exit 0 in 1.9 s -> `/nix/store/178k0k0k7hjppdwf24icpxdsyxxbnpdl-zix-0.2.0` (same path the new log records) |
| D7 | `diff -r /home/mei/nixos/tools/zix /home/mei/machine0/tools/zix --exclude=__pycache__` | empty (exit 0) |
| D8 | `diff -r /home/mei/nixos/tools/zix /home/mei/railway-nix-agent/vendor/zix --exclude=__pycache__` | empty (exit 0) |
| D9 | caveat text | present at `tools/zix/README.md:169-172`, present in both worktree mirrors; machine0 index hash == worktree hash (`e1fb4e9...`) |
| D10 | `podman ps -a` / `podman images` / `ps -p 282344` | ps -a empty; images = 6 entries incl. a live `ulw-a7-m0-agent:v5`; PID 282344 alive and now running `/home/mei/.cache/m0railway-a7/qa/run.sh` |
| D11 | `git status/diff` in machine0 and railway-nix-agent | machine0: staged-only, unstaged diff empty; railway: `AM README.md`, `AM vendor/zix/README.md` (index stale) |
| D12 | `journal.md:81-95`, `reference/self/observations.md` | BLOCK + each B1/B2/N1-N5 fix recorded; reflection line present |

## Delta-by-delta

### 1) report.html 308 -> 303 with the run band - RESOLVED
- `grep -c 308` = 0 in **both** `report.html` and `probe-run.html` (round 1 found three spots in
  each).
- The 303 value and the band are stated in every promoted place: exec summary `report.html:82`
  ("measured 303 MiB in the final run (398 MiB on a re-run; cgroup v2 counts page cache)"),
  SVG chart label `:140` (`>303<`), figcaption `:149-150` ("303 MiB in the final container run
  (a re-run measured 398 MiB; cgroup v2 counts page cache, so treat 300-400 MiB as the band)"),
  comparison cell `:161` ("peaks 303-398 MiB (512 MB = headroom risk)"), measured table `:181`
  ("394 MiB / 37.5 MB / 303 MiB"). `probe-run.html` mirrors this at 82/140/149-150/161/181.
- The 512 MB claim is now a bench observation: `report.html:84` ("a 512 MB plan remains a
  bench-level observation rather than a promise") and `railway-nix-agent/README.md:55-59`.
- Other promoted copies agree: `SYNTHESIS.md:179` = 303 MiB; `railway-nix-agent/README.md:48`
  = "303 MiB (final run; 398 MiB on a re-run)"; `:109` = "303 MiB container peak". A sweep of the
  whole session dir + the three READMEs finds no remaining 308-as-peak.

### 2) ulw-m0-zix-build2.out re-captured - RESOLVED for the log, NOT resolved for the bundle
- The log now records `zix-0.2.0` three times and `FINAL_ZIXBUILD_EXIT=0` (D4); the pre-fix capture
  is preserved as `ulw-m0-zix-build-pre-fix.out` (D5); `goals.json` G001/C001 `capturedEvidence`
  cites exactly this log, so the criterion citation is now consistent with "nix build .#zix ->
  zix-0.2.0". My own build reproduces the same store path (D6).
- **But** `G012-.../a0/cli-transcript.txt` - the frozen bundle artifact round 1's B2 named
  explicitly (reviewer file line 54) - is untouched (mtime 11:06:44, the fix landed 11:21-11:24)
  and still reads:

      === machine0 zix build (final) ===
      building '/nix/store/0y5qp1adjqp0c77zw6bp3f2jfxi7lsys-zix-0.1.0.drv'...
      /nix/store/ab7g67rnm4y6wy1c242y7ghkg7wdlg3p-zix-0.1.0
      ZIX_BUILD2_EXIT=0

  The gate bundle still contains a "(final)" `zix-0.1.0` transcript contradicting the claim it is
  assembled to prove, and nothing in the bundle annotates it as pre-fix (the bundle dir holds only
  these four files). Round 1 asked to "re-capture the ... transcript **into the bundle**"; only the
  evidence log was re-captured.

### 3) vendored mirrors re-synced - RESOLVED on disk, with one index note
- Both `diff -r` runs are empty (D7, D8); the "latest prefers servable / prebuilt store path"
  caveat (`tools/zix/README.md:169-172`) is present in all three trees.
- machine0 is genuinely re-staged: `git status --porcelain` shows staged paths only (23 A / 8 M),
  `git diff` empty, index blob == worktree blob (D9, D11).
- Note: **railway-nix-agent's index is stale** - `git status` shows `AM README.md` and
  `AM vendor/zix/README.md`; the staged `vendor/zix/README.md` blob (`a6cadba`) still lacks the
  caveat that the worktree copy (`e1fb4e9`) has. The mirrors are right on disk; only that repo's
  index disagrees with them.

### 4) "orphan harness killed, images removed" - FALSE at review time
- The worker is **not dead**. The build runs under child session `st_01a116bf`
  (`PI_SESSION_ID=01a116c0-7298-7c60-8742-dbe9eb2d6427`, transcript
  `.../children/st_01a116bf/sessions/st_01a116bf/2026-10-07T14-24-33.348Z_*.jsonl`, 3.4 MB,
  mtime 11:28:23 - i.e. writing during this review).
- Its harness is executing now: PID 282344 (started 11:25:37, still alive at 11:30) was
  `podman build -t ulw-a7-m0-agent:v5 ...` and has moved on to
  `bash /home/mei/.cache/m0railway-a7/qa/run.sh`; there are armed monitor tails on
  `/home/mei/.omo/ulw-a7/build/build14.log` and `/home/mei/.omo/ulw-a7/qa/qa.log`, and it is
  rewriting its drafts (`/home/mei/.cache/m0railway-a7/draft/{Dockerfile,DESIGN.md,RAILWAY.md}`
  at 11:26-11:27; `/home/mei/.omo/ulw-a7/draft/REPORT.md` at 11:23:48).
- `podman images` at 11:29:55:

      localhost/ulw-a7-m0-agent:v5   471cf87de8cb  49 seconds ago   1.37 GB
      <none>                        38be5583fb11  About a minute ago 2.67 GB
      docker.io/library/alpine:3.21  9cb701c20b59  2 weeks ago      8.1 MB
      docker.io/library/alpine:3.22  c83674e19990  2 weeks ago      8.59 MB
      localhost/railway-nix-agent:omo f07f11175e40 46 years ago     1.04 GB
      docker.io/nixos/nix:2.34.8    1047b32adacc  56 years ago      557 MB

  That is six entries, not the two claimed - and the 1.37 GB `ulw-a7-m0-agent` plus the untagged
  2.67 GB layer are exactly the pair round 1's N4 flagged and the lead reports removing. The
  `nixos/nix:2.34.8` base was pulled at 11:23:36, ~70 s **after** the claimed cleanup (archives at
  11:22:24). Only "`podman ps -a` is empty" holds.
- The reviewed repos are untouched by that lane: machine0's unstaged diff is empty and railway's
  two unstaged files predate this session (README.md mtime 11:20:58). So the deliverables stand;
  the *claim* does not.

### 5) journal + reflection line - RESOLVED
- `journal.md:81-95` records the round-1 BLOCK, the B1/B2 fixes, N1-N5 with their dispositions.
- `reference/self/observations.md` carries the 2026-10-07 late-numeric-edit line (BLOCK quoted,
  counted 2 of 2 blockers in my own artifacts, with the "grep every promoted copy" next-check).
- Stale sub-item: the N5 line ("/tmp/ulw-a7/npmtest needs sudo") no longer matches the machine:
  `/tmp/ulw-a7` is now a symlink to `/home/mei/.omo/ulw-a7` and holds only `draft/REPORT.md`;
  no `npmtest` exists there anymore.

## New blockers

**NB1 - the frozen gate bundle still contradicts the zix claim.**
`/home/mei/nixos/.omo/evidence/ulw/01a1169d-7430-7c51-98bd-b2335f35c855/G012-instrumentation-files-are-orchestrat/a0/cli-transcript.txt:6-9`
records `zix-0.1.0` under "=== machine0 zix build (final) ===" while G001/C001 and the re-captured log
say `zix-0.2.0`. This is the unresolved half of round 1's B2, inside the bundle the gate exists to prove.
Fix: re-capture that section from `evidence/ulw-m0-zix-build2.out`, or annotate it "pre-fix; superseded by
`ulw-m0-zix-build2.out`" - one edit, no code change.

**NB2 - delta item 4's state claim is false.**
The "dead dockerfile-design worker's orphan harness" is live child session `st_01a116bf`, currently
building (`ulw-a7-m0-agent:v5`) and running its QA; it has reintroduced the `ulw-a7` images
(`podman images` above). Refs: PID 282344 + `/home/mei/.cache/m0railway-a7/build/build15.log`
(mtime 11:28:01), `.../children/st_01a116bf/sessions/st_01a116bf/*.jsonl` (mtime 11:28:23),
`podman images` 11:29:55. Fix: either actually stop it (`task_cancel st_01a116bf` / kill its tree)
and redo the removal, or correct the claim to what round 1's N4 said - the containers/images belong
to a live sibling task - and do **not** checkpoint G012 asserting the harness was killed.

## Statement on the two original blockers

- **B1 - RESOLVED**: no promoted copy carries a 308 peak; 303 MiB with the 303-398 MiB run band and
  the softened 512 MB claim are in report.html (82/140/149-150/161/181), probe-run.html, SYNTHESIS.md
  and the railway README, and my own run of the cited measurement remains the 303 MiB sample.
- **B2 - PARTIALLY RESOLVED**: the criterion-cited log (`evidence/ulw-m0-zix-build2.out`) now proves
  `zix-0.2.0` (independently reproduced), but the other artifact B2 named - the frozen bundle's
  `cli-transcript.txt` - still prints the pre-fix `zix-0.1.0` build as "(final)"; see NB1.

## Notes (not criterion-cited)

- **N6**: railway-nix-agent's index is stale for `README.md` + `vendor/zix/README.md` (`AM`); re-stage
  so the staged tree matches the synced mirrors, as machine0 already is.
- **N7**: the journal's N5 line is stale (no `/tmp/ulw-a7/npmtest`; `/tmp/ulw-a7` is a symlink to a
  live draft dir).
- The a7 lane's activity does not touch the reviewed trees (D11); a re-review after NB1/NB2 is cheap.

## Cleanup receipt (reviewer's own QA resources)

- Spawned nothing: no server, no container, no tmux, no browser, no monitor, no temp file or dir.
- One `nix build .#zix --no-link --print-out-paths` (store-only, `--no-link`, no repo write) and
  `git status`/`git diff` in machine0 + railway-nix-agent. Those git reads refresh `.git/index` stat
  caches; no tracked content changed - machine0 still shows an empty unstaged diff, railway still
  shows exactly the two pre-existing fix deltas. No repository file was modified by this review.
- I did not touch the live a7 task (its processes, images and drafts are as found), per round 1's N4
  guidance; tearing it down is the lead's call (NB2).

## Delivery note

`task_send({ to: 'lead' })` is not addressable from this child; the verdict travels back through this
child's task result, which the host delivers to the lead. The lead should checkpoint G012 with this
verdict (BLOCK) and `by = "category:deep-low"` only after NB1 and NB2 are fixed, then re-review the
delta again.
