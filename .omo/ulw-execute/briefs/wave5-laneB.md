# Wave-5 lane B brief — todo 19 (non-tautological unit-script assertion)

Work ONLY in `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave5` (branch `thinkpad-zero-touch-install/wave5`, off main 7689b0c).
Read the plan (todo 19) and the F2 report first.

In `tests/dendritic-config-eval.nix` the `hasInfix "install" ... .script` assertion is
near-tautological (the embedded store path contains `/install`). Tighten it so it proves the
script actually invokes the app wrapper with the plan's flags: assert the script contains the
wrapper store path AND `--rescue-identity` AND `--host`. Do NOT weaken or renumber any other
assertion.

Acceptance: `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'`
prints PASS; flipping the script input in a scratch copy makes it fail (capture it).
Commit (exact): `test(iso): make the unit-script assertion non-tautological`

Evidence: `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-19-thinkpad-zero-touch-install.log`.
End with: `DoneClaim: {"task": "19: ...", "changed_files": [...], "tests": ["<cmd> => <result>"], "manual_qa": [...], "cleanup": [...], "risks": [...]}`
Scratch only under /tmp with receipts; `git show --stat HEAD` = only the eval file.
