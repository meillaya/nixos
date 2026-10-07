# Wave 1 lane brief — plan `thinkpad-zero-touch-install`

You are ONE LANE of a 5-lane parallel wave. Read the whole plan first: `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md`.
Further context is in `/home/mei/nixos/.omo/ulw-research/20261006-100350/` when the plan cites it.

## Your worktree — ALL edits, commands and tests happen here
- Worktree root: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave1` (branch `thinkpad-zero-touch-install/wave1`, based on main 5a33373).
- `cd /home/mei/nixos-wt/thinkpad-zero-touch-install-wave1` for every command. Use `git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave1 ...` for git.
- The plan and the research notes live in the main checkout; read them at `/home/mei/nixos/...`.
  When the plan's acceptance commands use the absolute path `/home/mei/nixos`, substitute
  your worktree root `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave1` — a `nix` flake evaluation of the MAIN checkout would NOT
  contain your uncommitted work.
- Other lanes edit OTHER files in this same worktree concurrently. Never edit files
  outside your scope. If a repo-wide `nix` evaluation fails inside a file outside your
  scope, wait/retry once (`nix` re-reads the tree), then report it; do not "fix" it.
- Because flake evaluation only sees the git tree, `git add` a NEW file before any
  `nix` flake command that must see it.

## Commit policy (plan `## Commit strategy`)
- One atomic commit per todo, message EXACTLY as the plan's `Commit:` line says.
- `git add` only your own explicit paths (never `git add -A`/`-u`); commit with
  `git commit -m '<message>' -- <paths>` style discipline.
- If `index.lock` contention happens (parallel lanes), wait a second and retry.
- Never commit a plaintext password, a staging tmpdir, or any `.direnv` path.
- Do not push, do not merge, do not rebase, do not touch other branches or the plan file.
- Do not edit anything under `/home/mei/nixos/.omo/` except your own evidence file.

## Evidence
Capture REAL command output (use `2>&1 | tee -a <evidence>`), then write your evidence
artifact(s) to `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-<N>-thinkpad-zero-touch-install.<ext>` for each todo N you own
(exact file names are in each todo's "Evidence" line). The evidence dir may not exist in
your worktree — write to that absolute main-checkout path.

## Completion protocol (mandatory, exact)
End your final message with one filled JSON object per todo you completed:
`DoneClaim: {"task": "<N: title>", "changed_files": [...], "tests": ["<exact command> => <result>"], "manual_qa": ["<artifact path>"], "cleanup": ["<receipt or none>"], "risks": [...]}`
Never claim a pass you did not observe. If something could not be executed, say exactly
why in `risks` instead of inventing a result.

## Adversarial probes (run each; record observable result, or `n/a — reason`)
## Your todo
- [ ] 4. Installer: `--extra-files`/`--chown` transport and the attempt marker
  What to do / Must NOT do: in `bin/host-install.sh` add `--extra-files <dir>` and repeatable `--chown <path> <owner>` pairs (usage, vars, parser arms before the `esac` at `:85`; forward each `--chown` verbatim and the `--extra-files` value in `stage_install` at `:201`, guarded on non-empty), mirror both in `print_plan` (`:111`), and write the attempt marker `: > /run/autoinstall-done` immediately before the nixos-anywhere call. The caller supplies the ownership paths; do NOT invent or default any `--chown` path here, do NOT touch the `/var/lib` trees, do NOT change the `--yes` re-check.
  Closes: GAP-1 (transport), GAP-4 (marker)
  Parallelization: Wave 1 | Blocked by: - | Blocks: 6, 9
  References: `bin/host-install.sh:36-43` (vars), `:45-86` (parser), `:91-120` (print_plan), `:193-206` (stage_install, the nixos-anywhere call at `:201`); upstream `--extra-files`/`--chown` semantics (tar to /mnt before install, modes preserved, root-owned; `--chown <path> <ownership>` = `chown -R /mnt/<path>` after the copy).
  Acceptance criteria (agent-executable): `bash -n bin/host-install.sh`; `bash bin/host-install.sh --dry-run --host antagony --extra-files /tmp/x --chown home/mei/.config 1000:100` prints a plan containing both; grep shows the marker write precedes the nixos-anywhere call.
  QA scenarios: happy - the dry-run above; failure - `--chown` with a missing owner argument or `--extra-files` with no value exits with usage (die_usage). Evidence `<attemptDir>/task-4-thinkpad-zero-touch-install.log`
  Recommended task executor category: deep-low
  Commit: Y | `feat(install): forward --extra-files/--chown and record the destructive attempt`


## Lane-specific adversarial probes
- malformed_input: `--chown` with a missing owner argument and `--extra-files` with no value must
  both exit 64 via `die_usage`; show the exact invocation and rc.
- misleading_success_output: `--dry-run` prints the plan (including both new flags and the marker
  step) and executes nothing; paste the full dry-run output.
- dirty_worktree: `git show --stat HEAD` lists only `bin/host-install.sh`.
- hung_or_long_commands: n/a — dry-run only, no real install is ever executed.
