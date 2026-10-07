# Wave-5 lane A brief — todos 17 + 18 (dead code + behavioral generator test)

Work ONLY in `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave5` (branch `thinkpad-zero-touch-install/wave5`, off main 7689b0c).
Read the plan `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md` (todos 17, 18) and the F2 report
`/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/F2-code-quality.md` first. Execute IN ORDER:

## Todo 17 — remove the unused `staging_plan` helper
`bin/_install-staging.sh`'s `staging_plan()` has zero call sites (F2 major 1). Remove the
function and any comment block that exists only for it. Do not change other helpers.
Acceptance: `grep -rn 'staging_plan' bin/ apps/ tests/ modules/` = 0 hits; `bash -n bin/_install-staging.sh` rc=0; `bash tests/install-staging.sh` PASS.
Commit (exact): `refactor(install): drop the unused staging_plan helper`

## Todo 18 — execute the staging generator in the pinned check
Extend `tests/install-staging.sh` with a BEHAVIORAL block: source `bin/_install-staging.sh`,
run `staging_init` + `staging_password <stage> <user>` with the real `mkpasswd`, and assert:
the hash file exists at `var/lib/nixos-bootstrap/<user>-password.hash`; dir 0700, file 0600;
content matches `^\$y\$[./A-Za-z0-9]+\$[./A-Za-z0-9]{1,86}\$[./A-Za-z0-9]{43}$`;
printed exactly once; no plaintext in the stage. Read `modules/flake/checks.nix` first and add
`pkgs.mkpasswd` to the check's nativeBuildInputs if the check's PATH lacks it. Keep the existing
token greps; do not weaken anything.
Acceptance: `bash tests/install-staging.sh` PASS twice; `nix build --no-link .#checks.x86_64-linux.install-staging` rc=0;
a scratch copy with a `mkpasswd` stub emitting garbage FAILS the new block.
Commit (exact): `test(install): execute the staging generator and assert its artifact`

## Evidence + DoneClaim
Write `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-17-thinkpad-zero-touch-install.log`
and `task-18-thinkpad-zero-touch-install.log`. End with TWO DoneClaims (one per todo):
`DoneClaim: {"task": "17|18: ...", "changed_files": [...], "tests": ["<cmd> => <result>"], "manual_qa": [...], "cleanup": [...], "risks": [...]}`

## Adversarial probes
misleading_success_output (the stub mutation must fail the new block), stale_state (re-run the
test twice), dirty_worktree (`git show --stat HEAD` per commit = only its files),
hung_or_long_commands (timeouts), flaky_tests (deterministic twice).
Scratch only under /tmp, cleaned with receipts. Disk ~270G free.
