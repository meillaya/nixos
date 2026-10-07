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
- [ ] 5. Installer PATH: mkpasswd
  What to do / Must NOT do: add `pkgs.mkpasswd` to `installDeps` in `modules/flake/apps.nix` (verified present on the pinned nixpkgs: `p.mkpasswd.pname == "mkpasswd"`). Do NOT change the other deps or the app registration.
  Closes: GAP-1 (tooling)
  Parallelization: Wave 1 | Blocked by: - | Blocks: 6
  References: `modules/flake/apps.nix:516-531` (`mkLinuxApps`, `installDeps`, the `install` binding); lead eval confirming the attr name.
  Acceptance criteria (agent-executable): `grep -Fq 'pkgs.mkpasswd' modules/flake/apps.nix`; `nix eval --impure --raw --expr '(builtins.getFlake (toString /home/mei/nixos)).apps.x86_64-linux.install.program'` succeeds.
  QA scenarios: happy - the eval above; failure - remove the line and confirm the task-3 helper fails to find mkpasswd via the wrapper (`nix run .#install -- --dry-run` path). Evidence `<attemptDir>/task-5-thinkpad-zero-touch-install.txt`
  Recommended task executor category: quick
  Commit: Y | `feat(install): put mkpasswd on the installer PATH`


## Lane-specific adversarial probes
- stale_state: run the plan's `nix eval` acceptance twice, paste both outputs (it must resolve the
  `install` app's program path with the new dep).
- dirty_worktree: `git show --stat HEAD` lists only `modules/flake/apps.nix`.
- malformed_input / misleading_success_output: n/a — a one-line dependency addition; the eval proves
  the attr resolves and the plan's failure scenario (removing the line) is asserted by grep.
- long_external_commands: wrap the eval in `timeout 900`.
