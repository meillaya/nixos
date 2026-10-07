# Wave-3 FIX brief — the autoinstall unit cannot reach the app (F-B)

Independent evidence from T14's VM test: with the gate open (`nixos.autoinstall=1`), the unit
`nixos-autoinstall.service` runs its script but the app wrapper dies immediately with
`env: 'bash': No such file or directory` (status 127) — and nix is missing too, per the T14
report. The plan (todo 9) requires the script to run
`${config.flake.apps.x86_64-linux.install.program} --host <host> --yes --rescue-identity`,
and todo 14 requires the VM test to observe "the app dies at the host-match check", so the
app must actually start. Work ONLY in `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (tip a1c86ad).

## Required fix (minimal)
1. Read `modules/flake/apps.nix:1-40` (mkApp) to see exactly what the wrapper needs: its
   shebang, its PATH construction, and which tools pathDeps provides. The wrapper itself
   exports a PATH once its interpreter starts; the missing piece is the interpreter
   (bash) and possibly env/coreutils for the shebang.
2. In `modules/flake/iso-images.nix`, give the `nixos-autoinstall` service what it needs —
   e.g. `path = [ pkgs.bash pkgs.coreutils pkgs.nix ]` (adjust to what mkApp actually
   requires; prefer `path` over hand-built Environment strings). Do NOT add `|| true`;
   keep every condition/unitConfig/serviceConfig field exactly as the t11 wall pins them.
3. If (and only if) the fix makes the app reachable, tighten `tests/iso-autostart-vm.nix`
   so the gatedBoot variant asserts the plan's literal requirement — the app dies at the
   host-match check (e.g. the journal shows the app's DMI/host mismatch message) — while
   keeping all existing durable assertions (gate opens, unit failed, rescue target active,
   no marker, no disk written).

## Verification (capture everything)
- Re-run: `timeout 3000 nix build .#checks.x86_64-linux.iso-autostart-vm --no-link` => must
  be rc=0, and the gatedBoot journal must show the app reached (its die message).
- Show the BEFORE symptom from the existing evidence log (the 127 line) and the AFTER proof.
- `bash -n`/`nix-instantiate --parse` the changed files; `git show --stat HEAD` = only your files.
- Disk is at ~5G free: if ENOSPC, stop and report (do NOT run nix store gc).
- Evidence: append to `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-9-thinkpad-zero-touch-install.json`? No — write a new
  `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/fix-unit-path-thinkpad-zero-touch-install.log`.

## Commit
Exact message: `fix(iso): give the autoinstall unit a usable PATH` (files: modules/flake/iso-images.nix, tests/iso-autostart-vm.nix if tightened).

## DoneClaim
`DoneClaim: {"task": "F-B fix: unit PATH", "changed_files": [...], "tests": ["<cmd> => <result>"], "manual_qa": ["<evidence>"], "cleanup": ["..."], "risks": [...]}`
