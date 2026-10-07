# F3 — Real manual QA (final verification wave)

You are the F3 QA executor for the plan `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md`.
Every implementation todo has landed and been verified; this is the plan's own F3 row:
"run `nix flake check --all-systems --no-build`, the full script suite, and the deliberate
validator proof (`unshare -Ur -m` against the produced hash); record transcripts."

## Where to run
- Worktree (identical tree to the landed main): `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3`
  (verify `git status --porcelain` is empty first; if not, STOP and report).
- Scratch copies under /tmp only. Do not mutate the worktree. Do not commit.

## Commands (run each; capture full output + rc)
1. `timeout 1800 nix flake check --all-systems --no-build` (from the worktree root).
2. The full script suite, each with `timeout 900`:
   `bash tests/dendritic-architecture.sh`, `bash tests/dendritic-boundaries.sh`,
   `bash tests/dendritic-apps.sh`, `bash tests/dendritic-shells.sh`,
   `bash tests/package-policy.sh`, `bash tests/install-staging.sh`,
   `bash tests/bootstrap-password-mutations.sh`.
   NOT `tests/bootstrap-password-lifecycle.sh` (deliberate manual destructive gate, excluded by plan).
3. The deliberate validator proof: source `bin/_install-staging.sh` under `unshare -Ur -m`,
   run `staging_init` + `staging_password <stage> mei` (a stub `mkpasswd` is acceptable if the
   real one is unavailable — prefer the real `mkpasswd` from the pinned nixpkgs), then run the
   REAL activation validator from `modules/nixos/bootstrap-password.nix` (extract the
   `bootstrapPasswordHash` logic) against the produced hash: expect rc=0, silent.
4. `nix build --no-link .#checks.x86_64-linux.install-staging` (if it builds cheaply — T10 proved it does).

## Known environmental notes (record, do not "fix")
- `tests/dendritic-architecture.sh` once hung at `fastfetch` (rc=124) in an early sandbox;
  later runs by other workers passed. If it hangs here, record the exact failure as an
  environmental result and continue with the rest.
- `nix build` of some checks may fail offline (flake input re-fetch); `--no-build` eval is the
  plan's acceptance. Record anything that cannot run with the exact reason.

## Output
Write a transcript-style record to
`/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/F3-manual-qa.md` containing every command,
its rc, and the decisive output lines (trim noisy build logs but never omit failures).
End your final message with:
`F3Report: {"flake_check": "<rc + summary>", "scripts": {"<name>": "<rc>"}, "validator_proof": "<rc + evidence>", "environmental": ["..."], "cleanup": ["..."]}`
