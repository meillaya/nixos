# Wave-5 independent verifier — todos 17, 18, 19 (F2 follow-up)

You did not implement this work. Verify adversarially; `confirmed` is the only pass verdict.
Plan: `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md` (todos 17-19). F2 report:
`/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/F2-code-quality.md`. Worker evidence:
`task-17/18/19-thinkpad-zero-touch-install.log` in the same dir.

Worktree under verification: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave5` (branch `thinkpad-zero-touch-install/wave5`; chain
7689b0c -> 006c314 -> be2ac14 -> 11f544a). Record the tip; if it moves, verify at the current tip.

## Verify per todo
1. **17 (dead code)**: `grep -rn 'staging_plan' bin/ apps/ tests/ modules/` = 0 hits; `bash -n bin/_install-staging.sh`;
   `git show --stat 006c314` = only that file; no behavior change in the remaining helpers (diff review).
2. **18 (behavioral generator test)**: re-run `bash tests/install-staging.sh` (twice, deterministic) and
   `timeout 1800 nix build --no-link --rebuild .#checks.x86_64-linux.install-staging` (force a real run) =>
   rc=0 and the log shows the behavioral block executing (`staging_init` + `staging_password` against the
   real `pkgs.mkpasswd`); in a /tmp scratch copy, stub `mkpasswd` to emit garbage => the new block FAILS
   with the regex message; confirm the block is behavioral, not token greps (read the code).
   Also confirm `pkgs.mkpasswd` was added to the check's deps in `modules/flake/checks.nix`.
3. **19 (non-tautological assertion)**: read the diff (`git show be2ac14`); run
   `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'` => PASS;
   two scratch flips (drop `--host antagony`; strip the wrapper store-path token) each FAIL; confirm no
   other assertion was weakened or renumbered.
4. **Cross-cutting**: `timeout 1800 nix flake check --all-systems --no-build` => rc=0;
   `git status --porcelain` empty at the end; per-commit file lists match.

## Output
Write `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/wave5-verification.json` with
`{"verified_tip", "todos": {"17","18","19"} with verdict/evidence/repro/confidence, "adversarial": {...}, "cleanup": [...]}`
and report it in your final message. Scratch only under /tmp with cleanup receipts. Disk ~270G free;
never nix store gc. NOTE: do not run `kill_bash all` — other sessions may be live; kill only your own.
