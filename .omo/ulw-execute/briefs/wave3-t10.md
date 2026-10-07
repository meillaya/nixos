# Wave 3 lane brief — plan `thinkpad-zero-touch-install`

You are ONE LANE of a parallel wave executing the work plan `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md`.
Read the whole plan first, then your todo section below (verbatim from the plan).

## Your worktree — ALL edits, commands and tests happen here
- Worktree root: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (branched from `main` AFTER the previous wave landed).
- `cd /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` for every command; use `git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3 ...` for git.
- The plan and research notes live in the main checkout; read them at `/home/mei/nixos/...`.
  Where the plan's acceptance commands use `/home/mei/nixos`, substitute the worktree
  root `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` — a flake evaluation of the MAIN checkout would not contain your work.
- Sibling lanes edit OTHER files concurrently in this same worktree. Never edit files
  outside your scope. If a repo-wide `nix` evaluation fails inside another lane's file,
  retry once, then report; do not fix it.
- Flake evaluation only sees the git tree: `git add` a NEW file before any `nix` flake
  command that must see it.
## Inter-wave context
- Waves 1-2 are merged into main and your worktree is off that main: the staging helper,
  the app staging/identity/rescue/verify-host-match flow, the ISO gated unit + `flake.isoConfig`,
  and the operator-path staging all exist. Read the actual files; do not assume from memory.

## Commit policy
- One atomic commit per todo, message EXACTLY as the plan's `Commit:` line says.
- `git add` only your own explicit paths (never `git add -A`/`-u`). On `index.lock`
  contention, wait a second and retry. Never commit a plaintext password, a staging
  tmpdir, or any `.direnv` path. Do not push/merge/rebase/touch other branches or the plan.
- Do not edit anything under `/home/mei/nixos/.omo/` except your own evidence file.

## Evidence
Capture REAL command output (`2>&1 | tee -a <evidence>`), then write your evidence
artifact(s) to `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-<N>-thinkpad-zero-touch-install.<ext>` for each todo N you own
(exact names in the todo's "Evidence" line).

## Completion protocol (mandatory, exact)
End your final message with one filled JSON object per todo you completed:
`DoneClaim: {"task": "<N: title>", "changed_files": [...], "tests": ["<exact command> => <result>"], "manual_qa": ["<artifact path>"], "cleanup": ["<receipt or none>"], "risks": [...]}`
Never claim a pass you did not observe; record unexecutable steps in `risks` with the reason.

## Adversarial probes (run each; record observable result, or `n/a — reason`)
## Your todo
- [ ] 10. Tests: staging invariants and the app/dry-run greps
  What to do / Must NOT do: create `tests/install-staging.sh` asserting the invariants (mkpasswd `--method=yescrypt`/`--stdin`; `--extra-files` present in BOTH the app and `bin/host-install.sh`; `--chown` forwarding; `nixos-bootstrap` + `nixos-enrollment` paths; `keys.txt` staging; the `$y$` regex; `0700`/`0600`; `unset pw`; exactly one `password for` print; `--dry-run` prints no secret) and wire it into `modules/flake/checks.nix` following the `dendritic-boundaries` shape; extend `tests/dendritic-apps.sh` dry-run greps with the `--extra-files` step. Do NOT wire `tests/bootstrap-password-lifecycle.sh` (bind mounts + sandbox) - probe `unshare` viability first and record the verdict in the test header if skipped.
  Closes: GAP-7
  Parallelization: Wave 3 | Blocked by: 7,8 | Blocks: -
  References: `modules/flake/checks.nix:5-15` (the `runCommand` check shape; boundaries itself is `:17-27`), `tests/dendritic-apps.sh:27-29` (dry-run greps), `tests/bootstrap-password-lifecycle.sh:16-39` (the bind-mount harness that stays manual).
  Acceptance criteria (agent-executable): `bash tests/install-staging.sh` exits 0; each assertion textually fails when its token is removed (spot-check two); `bash tests/dendritic-apps.sh` passes.
  QA scenarios: happy - run both scripts; failure - mutate one token in a scratch copy and confirm the check fails. Evidence `<attemptDir>/task-10-thinkpad-zero-touch-install.log`
  Recommended task executor category: unspecified-low
  Commit: Y | `test(install): pin the staging and transport invariants`


## Lane-specific adversarial probes
- flaky_tests: run `bash tests/install-staging.sh` and `bash tests/dendritic-apps.sh` TWICE each; deterministic pass both times.
- misleading_success_output: mutate one token in a scratch copy and show the new check FAILS (the plan's spot-check requirement: two assertions, not just one).
- stale_state: the checks must read the repo's actual files (no cached copies); show a token removal makes the run fail.
- dirty_worktree: `git show --stat HEAD` lists only the test files + `modules/flake/checks.nix` if wired.
- hung_or_long_commands: wrap `nix flake check --all-systems --no-build` in `timeout 1500`.
