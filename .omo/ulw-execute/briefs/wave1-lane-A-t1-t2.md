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
## Your todos (execute IN ORDER: first todo 1, commit, then todo 2, commit)
Both touch `modules/flake/iso-images.nix` — same lane, sequential, that is why they share you.

- [ ] 1. ISO: make the enrollment base record actually land
  What to do / Must NOT do: in `modules/flake/iso-images.nix`, replace the runtime `printf ... > /etc/hardware-enrollment/${host}.json` with a declarative `environment.etc."hardware-enrollment/${host}.json".text = baseDeclaration;` (keeps the same path for the oneshot's `--base`). Keep the `|| true` on the auto-enroll call but append a journal-visible failure marker (e.g. `|| echo "hardware-enroll: masked failure (artifact presence is the gate)" >&2`). Do NOT change the oneshot's unit name, ordering, or the `/root/enroll` trust path.
  Closes: GAP-6
  Parallelization: Wave 1 | Blocked by: - | Blocks: -
  References: `modules/flake/iso-images.nix:33-51` (the enrollment module; line 44 is the write; line 43 only mkdirs `/root/enroll`); `config/hosts/intake/README.md` (artifact paths); `tests/dendritic-architecture.sh:49` (feature file must keep existing).
  Acceptance criteria (agent-executable): `nix eval --impure --json --expr 'let c = (builtins.getFlake (toString /home/mei/nixos)).iso.antagony.passthru.config; in c.environment.etc."hardware-enrollment/antagony.json".text'` contains `"hostId": "antagony"`; `nix build .#iso.antagony --dry-run` evaluates.
  QA scenarios (name the exact tool + invocation): happy - `nix eval` the etc text (contains hostId); failure - temporarily remove the etc entry and confirm the eval assertion fails (then restore). Evidence `<attemptDir>/task-1-thinkpad-zero-touch-install.json`
  Recommended task executor category: quick
  Commit: Y | `fix(iso): land the enrollment base record declaratively`

- [ ] 2. ISO: btrfs support and the module at boot
  What to do / Must NOT do: add a new ISO-only module (alongside `enrollment`/`installerMarker`) with `boot.supportedFilesystems = [ "btrfs" "vfat" ]` and `boot.kernelModules = [ "btrfs" ]`, and add it to the `extendModules` module list at `iso-images.nix:60`. Do NOT touch `nixosConfigurations.<host>` (extendModules is ISO-only); do NOT add `nixos.autoinstall` anywhere.
  Closes: GAP-5
  Parallelization: Wave 1 | Blocked by: - | Blocks: 9, 11
  References: `modules/flake/iso-images.nix:52-61`; research VA2 (`iso.antagony` today: `supportedFilesystems = {iso9660,overlay,squashfs,tmpfs}`, `btrfsProgs=false`); `modules/nixos/disk-config.nix:68-84` (btrfs subvolumes).
  Acceptance criteria (agent-executable): `nix eval` shows `boot.supportedFilesystems` contains `btrfs` and `vfat`, `boot.kernelModules` contains `btrfs`, and `system.fsPackages` contains a `btrfs-progs` entry, for BOTH `iso.antagony` and `iso.remembrance`.
  QA scenarios: happy - the eval above returns true for both hosts; failure - assert the pre-change values are gone (`btrfsProgs=false` no longer holds). Evidence `<attemptDir>/task-2-thinkpad-zero-touch-install.json`
  Recommended task executor category: deep-low
  Commit: Y | `feat(iso): btrfs/vfat support and boot-loaded btrfs module`


## Lane-specific adversarial probes
- stale_state: after each edit, run the acceptance `nix eval` TWICE and paste both outputs;
  prove the eval reflects the edited file (the new text/attr must appear). If `passthru.config`
  or another accessor in the plan's acceptance command does not exist, adapt the command
  (e.g. use the ISO's `extendModules` config directly) — record the exact command you used.
- misleading_success_output: the auto-enroll `|| true` masks failures by design; grep the file
  to show the journal-visible failure marker exists on the failure path, and that the `--base`
  path still matches the declarative `/etc/hardware-enrollment/${host}.json` path.
- dirty_worktree: after each commit, `git status --porcelain` must show only files from the
  OTHER lanes (never yours), and `git show --stat HEAD` must list only your files.
- hung_or_long_commands: wrap long nix commands in `timeout 900 ...`; run `nix build .#iso.antagony
  --dry-run` (dry-run only — never a real ISO build).
