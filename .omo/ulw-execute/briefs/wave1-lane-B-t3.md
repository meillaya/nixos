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
- [ ] 3. Installer: shared staging builder `bin/_install-staging.sh`
  What to do / Must NOT do: new sourced-by-nobody-yet helper (underscore-private, matching `_host_key_enroll.py`) exposing: `staging_init` (`mktemp -d` under tmpfs, `trap 'rm -rf' EXIT`), `staging_password <stage> <user>` (pipefail-safe generator `pw="$(head -c 512 /dev/urandom | base64 -w0 | tr -dc 'A-Za-z0-9' | cut -c1-24)"`, `printf '%s\n' "$pw" | mkpasswd --method=yescrypt --stdin`, validate against the exact module regex BEFORE writing, `install -d -m 0700` + write 0600 + `stat` self-check 0:0:700/0:0:600, print exactly once, `unset pw`), `staging_artifacts <stage> <files...>` (0600 into a 0700 `var/lib/nixos-enrollment`), `staging_identity <stage> <user> <uid> <gid> <keyfile>` (0600 at `home/<user>/.config/sops/age/keys.txt`, reported chown target `home/<user>/.config`), `staging_plan` (dry-run text). Do NOT write plaintext anywhere; do NOT chown anything; do NOT keep a copy on disk beyond the tmpfs path.
  Closes: GAP-1 (partial), GAP-2 (partial)
  Parallelization: Wave 1 | Blocked by: - | Blocks: 6, 7
  References: recovered original `f7015a56:bin/nixos-anywhere-bootstrap-password.sh` (tmpfs stage, `install -d -m 700`, pinned mkpasswd, regex validation) via `.omo/ulw-research/20261006-100350/wave-1-lane2.md`; validator contract `modules/nixos/bootstrap-password.nix:44-84`; lifecycle expectations `tests/bootstrap-password-lifecycle.sh:182-250`.
  Acceptance criteria (agent-executable): `bash -n bin/_install-staging.sh`; sourcing it in a scratch shell and calling `staging_password` produces a file whose `stat -c '%a'` is 600 inside a 700 dir and whose content matches `^\$y\$[./A-Za-z0-9]+\$[./A-Za-z0-9]{1,86}\$[./A-Za-z0-9]{43}$`; the printed password is emitted exactly once.
  QA scenarios: happy - run the function in a tmpdir and assert modes+regex; failure - stub `mkpasswd` to exit 1 and assert the helper dies without writing the file; run the produced hash through the real validator under `unshare -Ur -m` (deliberate manual step; expect rc=0 silent). Evidence `<attemptDir>/task-3-thinkpad-zero-touch-install.log`
  Recommended task executor category: deep-low
  Commit: Y | `feat(install): shared staging builder for the password and payload`


## Lane-specific adversarial probes
- malformed_input: after the happy path, stub `mkpasswd` to `exit 1` on PATH and prove the helper
  dies non-zero WITHOUT writing any password file into the stage; also feed a `mkpasswd` stub that
  prints a string failing the regex and prove the helper refuses to write it.
- misleading_success_output: prove the password is printed exactly once; capture that no plaintext
  password is left anywhere under the stage after the run except the hash file, and that the helper
  never writes plaintext to disk.
- stale_state: prove `staging_init` always yields a fresh `mktemp -d` under tmpfs (run twice, paths
  differ, both cleaned on EXIT via the trap).
- dirty_worktree: `git status --porcelain` / `git show --stat HEAD` show only your new file.
- long_external_commands: the `unshare -Ur -m` validator proof is a deliberate manual step — run it
  with `timeout 120`; if the host sandbox refuses `unshare`, record the exact error as the result
  and mark the step `blocked by sandbox` (do NOT silently skip).
