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
- [ ] 14. Tests: the gate-inertness VM
  What to do / Must NOT do: add a `pkgs.testers.runNixOSTest` (nixpkgs VM framework, the repo's first) that boots the ISO's extended config as a test machine (the same config `flake.isoConfig.<host>` exposes) in two variants: (a) default kernel params - assert `systemctl is-active nixos-autoinstall.service` is `inactive` and `/run/autoinstall-done` does not exist (a plain boot touches nothing); (b) `boot.kernelParams = [ "nixos.autoinstall=1" ]` (test-only override) - assert the unit `nixos-autoinstall.service` starts, the app dies at the host-match check (a VM is not the ThinkPad), the rescue target activates, and no disk was written. Wire it as `checks.<system>.iso-autostart-vm` in `modules/flake/checks.nix`. Do NOT wire a full `=1` install run into flake checks (that is a deliberate manual step); do NOT use a real machine.
  Closes: GAP-4, GAP-7
  Parallelization: Wave 3 | Blocked by: 9 | Blocks: -
  References: `modules/flake/iso-images.nix` (the extended config to boot), `modules/flake/checks.nix:5-15` (check wiring), nixpkgs `pkgs.testers.runNixOSTest` docs; the gate semantics (`ConditionKernelCommandLine` prevents activation entirely). The unit name is `nixos-autoinstall.service` throughout.
  Acceptance criteria (agent-executable): `nix build .#checks.x86_64-linux.iso-autostart-vm` exits 0; removing the `ConditionKernelCommandLine` line makes variant (a) fail.
  QA scenarios: happy - the build above (both variants inside one test); failure - flip the condition in a scratch copy and confirm variant (a) fails. Evidence `<attemptDir>/task-14-thinkpad-zero-touch-install.log`
  Recommended task executor category: unspecified-high
  Commit: Y | `test(iso): prove the gate is inert on a plain boot`


## Lane-specific adversarial probes
- flaky_tests: the VM test must be deterministic — run `nix build .#checks.x86_64-linux.iso-autostart-vm` once to completion and report the exact result; if it fails, fix and re-run; no timing assumptions in assertions (use systemctl is-active / file existence checks).
- hung_or_long_commands: the VM build is long — wrap in `timeout 3000` and capture the log.
- misleading_success_output: removing `ConditionKernelCommandLine` must make variant (a) fail — demonstrate in a scratch copy (a separate `nix build` of the mutated config) or explain exactly why the machinery guarantees it; the plan requires the mutation proof.
- stale_state: boot both variants in ONE test run; the `=1` variant must show the unit started, host-match death, rescue target active, no disk written.
- dirty_worktree: `git show --stat HEAD` lists only `modules/flake/checks.nix` (+ a test file it must add).
