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
- [ ] 11. Tests: the ISO eval wall
  What to do / Must NOT do: extend `tests/dendritic-config-eval.nix` with the `flake.isoConfig.antagony.config` assertions: `btrfs`+`vfat` in `boot.supportedFilesystems`, `btrfs` in `boot.kernelModules`, `hasInfix` the enrollment JSON text, `variant_id == "installer"`, the unit's `wantedBy`/`wants`/`after`/`ConditionKernelCommandLine`/`ConditionPathExists`/`SuccessAction`/`OnFailure`/`Type`/`RemainAfterExit`/`StandardOutput`, the script containing `install` and `--rescue-identity`, and the NEGATIVE `!(builtins.elem "nixos.autoinstall=1" iso.boot.kernelParams)`. Do NOT weaken existing assertions or renumber the todo list.
  Closes: GAP-7
  Parallelization: Wave 3 | Blocked by: 2,9 | Blocks: -
  References: `tests/dendritic-config-eval.nix:13-15,146,232` (existing patterns), the `flake.machineAuthority` exposure pattern in `modules/entities/defaults.nix`/`flake` outputs, the ultrabrain assertion list (research session journal).
  Acceptance criteria (agent-executable): `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'` prints PASS; removing the condition makes it fail.
  QA scenarios: happy - the eval above; failure - flip the negative assertion input in a scratch copy and confirm failure. Evidence `<attemptDir>/task-11-thinkpad-zero-touch-install.log`
  Recommended task executor category: unspecified-low
  Commit: Y | `test(iso): pin the autostart unit and the inert-by-default assertion`


## Lane-specific adversarial probes
- misleading_success_output: the NEGATIVE assertion must be able to fail — in a scratch copy flip the condition input and show the eval aborts; never weaken existing assertions.
- stale_state: run the eval twice; the assertions must reflect the current files.
- dirty_worktree: `git show --stat HEAD` lists only `tests/dendritic-config-eval.nix`.
- malformed_input / flaky_tests / hung_or_long_commands: n/a — pure eval; wrap the eval in `timeout 900`.
