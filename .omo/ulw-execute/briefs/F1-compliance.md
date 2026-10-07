# F1 — Plan compliance audit (final verification wave)

You audit the finished plan `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md` (read it fully).
No implementation was yours; you verify, you do not fix.

## Scope (the plan's own F1 row)
"every todo's acceptance was run; every Must-NOT holds (grep for `nixos.autoinstall=1` outside
docs/tests; no plaintext password; no `|| true` in the unit)."

## Method
- Repo state: bundled/landed on `main`; an identical read-only copy exists at `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3`
  (run commands there; do NOT edit anything).
- For each of todos 1-15: read the plan's acceptance criteria. Check the ledger
  `/home/mei/nixos/.omo/ulw-execute/ledger.jsonl` and the evidence files
  `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-<N>-*` and the wave verification
  JSONs (`wave1-verification.json`, `wave2-verification*.json`, `wave3-verification.json`)
  for a recorded command + result matching each acceptance criterion. Spot-check at least
  SIX criteria by re-running the command yourself in the worktree copy.
- Must-NOT audit (each: PASS/FAIL + the grep/command):
  1. `nixos.autoinstall=1` appears ONLY in docs/tests, never in `boot.kernelParams` or a
     unit default: `grep -rn 'nixos.autoinstall' modules/ apps/ bin/ tests/ docs/ README.md`
     and eval `iso.antagony`'s `boot.kernelParams` in the worktree.
  2. No plaintext password written to disk/store/tracked file: grep the diffs + evidence
     logs for `password for` occurrences in files; the only print is the helper's stdout.
  3. No `|| true` (or equivalent masking) in the nixos-autoinstall unit; the ISO auto-enroll
     keeps its journal-visible failure marker.
  4. No `--chown` outside the staged `home/<user>/.config` subtree (grep the app +
     host-install for `--chown`).
  5. No `specialArgs`/`extraSpecialArgs`, no `nixosSystem`/`darwinSystem` calls added,
     no second install entry point: `git log -p main~1..` style review of the delivered diffs.
  6. `tests/bootstrap-password-lifecycle.sh` was NOT wired into flake checks.
- Also verify: the delivery mode was direct; every plan checkbox in `## TODOs` `- [x]` and
  the wave branches landed (git log on main shows the wave commits).


## Known deviations to adjudicate (recorded in the ledger — audit each, PASS/FAIL + rationale)
1. Todo 12 landed as TWO commits (`bde4937` + `b210a75`, a sandbox-HOME fixup) instead of one — the plan says one commit per todo; the fixup was forced by the flake-check sandbox.
2. Todo 13's docs commit was rewritten (`ae0a3ef` -> `0cc6c55`) to drop a force-added `bin/AGENTS.md`; the repo excludes ALL `AGENTS.md` via `.git/info/exclude` and tracks none — the local file was preserved (sha-verified) and is intentionally untracked. T10's commit was replayed (`a25219f` -> `19e2e11`).
3. A wave-2 verification fix commit exists (`bf90e20`, conditional `--chown`) — found by the independent verifier; the plan's one-commit-per-todo rule predates it.
4. A wave-3 fix commit exists (`5d4052f`, unit PATH) — found by the todo-14 VM test.
5. An incident: a T15 QA harness truncated two tracked intake files to 0 bytes; the orchestrator restored them from HEAD and the verifier re-confirmed byte-identity — no commit carries a truncated version.
6. F-A (ISO bootability) may be unresolved at audit time — treat an unresolved F-A as an OPEN finding for F4, not a plan-compliance failure of todos 1-14.

## Output
Write `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/F1-compliance.md` with a per-todo
acceptance table (criterion -> recorded evidence -> your re-check verdict) and a Must-NOT
table (item -> command -> PASS/FAIL). End your message with:
`F1Report: {"verdict": "APPROVE|REJECT", "rechecked": [<n criteria you re-ran>], "must_nots": {"<n>": "PASS|FAIL"}, "shortfalls": ["..."]}`
A shortfall is a REAL deviation, not a style nit; REJECT only with a concrete failing command
or an unmet acceptance criterion.
