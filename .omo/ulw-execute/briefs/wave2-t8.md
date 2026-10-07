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
- [ ] 8. App: `--rescue-identity` and the host/disk match
  What to do / Must NOT do: add `--rescue-identity` (mount the live layout read-only - `mount -o ro,nologreplay,subvol=/@home /dev/disk/by-id/<disk>-part2 <mnt>`; fall back to enumerating `subvolid=5`; copy `~/.config/sops/age/keys.txt` into the stage; unmount; die if not found when the flag is set; refuse outside a live root). Add `verify_host_match()` between `enroll()` and the fold/build: Phase P (pending record) - the DMI product must map to `--host`, else die with no override; Phase E (enrolled record) - compare the candidate against the baked record on `storage.diskById`, `storage.expected.{sizeBytes,logicalSectorBytes,modelSha256,serialSha256}`, `cpuVendor`. Do NOT make the rescue automatic; do NOT re-implement probe serialization.
  Closes: GAP-3, GAP-4 (host match)
  Parallelization: Wave 2 | Blocked by: 6 | Blocks: 9, 10
  References: `apps/x86_64-linux/install:146-151` (DMI map), `:229-286` (enroll; the candidate), `:236-243` (base record materialization); live subvolumes `@`/`@home`/`@root` (`/proc/mounts`); research VA8 (mount works; btrfs module present).
  Acceptance criteria (agent-executable): `--dry-run --rescue-identity` prints the rescue step; a run with `--host` mismatching the DMI dies before any staging; with an enrolled record the candidate-vs-baked comparison is enforced (unit-testable via a scratch record pair).
  QA scenarios: happy - dry-run + a scratch pair equality test; failure - mismatched host/model dies with a clear message. Evidence `<attemptDir>/task-8-thinkpad-zero-touch-install.log`
  Recommended task executor category: deep-low
  Commit: Y | `feat(install): rescue the live age identity and verify host/disk bindings`


## Lane-specific adversarial probes
- malformed_input: `--host` mismatching the DMI product must die with a clear message BEFORE any staging; a scratch candidate-vs-baked record pair with a differing field must be rejected.
- misleading_success_output: `--dry-run --rescue-identity` prints the rescue step; the rescue path must DIE when the key is not found while the flag is set (no silent success).
- stale_state: mounting read-only must not mutate anything; unmount always happens (assert no leftover mount in a scratch simulation).
- dirty_worktree: `git show --stat HEAD` lists only `apps/x86_64-linux/install`.
- hung_or_long_commands: mount/copy operations wrapped in timeouts; never mount the real system disk.
