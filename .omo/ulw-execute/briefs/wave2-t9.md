# Wave 2 lane brief — plan `thinkpad-zero-touch-install`

You are ONE LANE of a parallel wave executing the work plan `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md`.
Read the whole plan first, then your todo section below (verbatim from the plan).

## Your worktree — ALL edits, commands and tests happen here
- Worktree root: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave2` (branched from `main` AFTER the previous wave landed).
- `cd /home/mei/nixos-wt/thinkpad-zero-touch-install-wave2` for every command; use `git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave2 ...` for git.
- The plan and research notes live in the main checkout; read them at `/home/mei/nixos/...`.
  Where the plan's acceptance commands use `/home/mei/nixos`, substitute the worktree
  root `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave2` — a flake evaluation of the MAIN checkout would not contain your work.
- Sibling lanes edit OTHER files concurrently in this same worktree. Never edit files
  outside your scope. If a repo-wide `nix` evaluation fails inside another lane's file,
  retry once, then report; do not fix it.
- Flake evaluation only sees the git tree: `git add` a NEW file before any `nix` flake
  command that must see it.
## Inter-wave context
- Wave 1 is merged into main and your worktree is off that main: `bin/_install-staging.sh`
  (staging_init/staging_password/staging_artifacts/staging_identity/staging_plan),
  `bin/host-install.sh` `--extra-files`/`--chown`/attempt-marker transport, `pkgs.mkpasswd`
  in apps.nix installDeps, ISO btrfs support, and tests/bootstrap-password-mutations.sh all exist.
  Read the actual files; do not assume signatures from memory.

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
- [ ] 9. ISO: bake the flake, add the gated unit and the rescue target
  What to do / Must NOT do: add `inputs` to `modules/flake/iso-images.nix` args; add a `nixos-autoinstall` service (unit name `nixos-autoinstall.service`, referenced consistently everywhere) inside the ISO extension: `wantedBy = [ "multi-user.target" ]`, `wants = [ "network-online.target" ]`, `after = [ "network-online.target" "sshd.service" "hardware-enroll.service" ]`, `unitConfig = { ConditionKernelCommandLine = "nixos.autoinstall=1"; ConditionPathExists = "!/run/autoinstall-done"; SuccessAction = "reboot"; OnFailure = [ "iso-install-rescue.target" ]; }`, `serviceConfig = { Type = "oneshot"; RemainAfterExit = true; StandardOutput = "journal+console"; StandardError = "journal+console"; }`, script running `${config.flake.apps.x86_64-linux.install.program} --host <host> --yes --rescue-identity`; add the `iso-install-rescue.target` plus a tty1 debug service (`bash -i`, `StandardInput = "tty-force"`, `TTYPath = "/dev/tty1"`); expose `flake.isoConfig = lib.genAttrs isoHosts (host: <the extendModules config>)` and build `flake.iso` from it. Do NOT add `nixos.autoinstall=1` to `boot.kernelParams`; do NOT add `|| true` to this unit; do NOT patch grub.
  Closes: GAP-4
  Parallelization: Wave 2 | Blocked by: 2,4,6,8 | Blocks: 11
  References: `modules/flake/iso-images.nix:22-61` (args, extendModules); `modules/flake/apps.nix:9-21` (the wrapper: PATH deps + `exec ${self}/apps/...`); ultrabrain unit contract (research session journal); systemd `ConditionKernelCommandLine`/`SuccessAction`/`OnFailure` semantics.
  Acceptance criteria (agent-executable): the eval wall (todo 11) passes, including the negative assertion that `nixos.autoinstall=1` is absent from `boot.kernelParams`; `nix build .#iso.antagony --dry-run` evaluates.
  QA scenarios: happy - eval the unit fields; failure - delete the condition and confirm the wall fails. Evidence `<attemptDir>/task-9-thinkpad-zero-touch-install.json`
  Recommended task executor category: unspecified-high
  Commit: Y | `feat(iso): opt-in gated auto-install with a rescue target`


## Lane-specific adversarial probes
- misleading_success_output: NO `|| true` in the new unit; failure must land in the rescue target (grep the unit definition + eval `OnFailure`).
- stale_state: `flake.iso` must now be built FROM `flake.isoConfig` (assert `nix eval` of both sees the same extended config); rebuild-free eval must show the new unit after edits.
- dirty_worktree: `git show --stat HEAD` lists only `modules/flake/iso-images.nix` (plus nothing else).
- hung_or_long_commands: `nix build .#iso.antagony --dry-run` under `timeout 900`; no real ISO build.
- generated_or_cached_artifacts: the unit's script must reference the app wrapper path from the flake (no hardcoded store path drift).
