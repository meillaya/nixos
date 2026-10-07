# Wave 2 — lane10 (repo gaps) + lane11 (password proof, static) — completed

## lane10 — repo gap map (file:line, verified)

Ordered flow today: build ISO -> boot -> `nix run github:...install -- --yes` (app fetched from
GitHub, NOT baked into the ISO) -> DMI detect -> work tree on tmpfs -> gen_trust (fleet branch for
antagony; needs NO sops) -> auto_enroll (probe + intake + fresh host key 0600) -> commit -> fold
(requires `secrets/remembrance-keys.yaml` in the work tree -> absent, so `want_save`) -> `--save` ->
self-SSH -> live-root guard -> `host-install.sh --install-only` -> `nh os build` -> `nixos-anywhere`
(NO --extra-files, no password staging) -> disko + nixos-install -> first activation.

Gaps (each with the smallest fix):
- G1 no password staging anywhere in bin/ or apps/ (grep: 0 hits); the validator's fresh-state branch
  `fail "missing $hash_file"` means the contract is violated on every fresh install. Fix: restore the
  historical staging (mkpasswd yescrypt -> --extra-files -> --chown var/lib/nixos-bootstrap 0:0).
  BLOCKS zero-touch. PORT, verbatim from wave-1-lane2.md.
- G2 no artifact persistence without --save (tmpfs work tree). Fix: stage the enrollment artifacts
  into the target's persistent /var/lib/nixos-enrollment via the same --extra-files. BLOCKS no-USB.
  PORT the historical idea (it already staged into /var/lib).
- G3 no autostart (only `hardware-enroll` runs, and only probes; `|| true` hides its failure). Fix:
  second oneshot + gate. BLOCKS zero-touch. NEW work.
- G4 no ISO/oneshot test coverage (checks.nix has 7 checks, none ISO; hardware-enroll never tested).
  Fix: re-add the deleted mutation test + an ISO VM test.
- G5 fold depends on a store this laptop cannot decrypt (&admin/&recovery vs &workstation). Fix: drop
  the fold from the ThinkPad path (host key becomes a staged artifact) or extend the .sops.yaml rule.
- G6 the install app is not carried by the ISO (fetched from GitHub). Fix: bake the app+flake into the
  image for a no-network install.
- G7 the ISO's enrollment oneshot needs an operator-staged trust fixture (fail-closed). Fix: call
  gen_trust in the oneshot (the app already does).

Port-vs-reinvent: G1/G2/G5 are one restoration of the historical design; G3 + G4 are the only new work.

## lane11 — password proof (static; execution handed to the lead)

- The symlink hole flagged at `d4f2559` is CLOSED at HEAD: `test ! -L` runs BEFORE `-e` for both the
  hash dir (L44) and file (L56) — a dangling symlink fails as "expected a regular file".
- nixpkgs' own VM test `nixos/tests/password-option-override-ordering.nix` (at the flake's pinned rev)
  asserts **hashedPasswordFile WINS** and describes the old warning order as "in fact wrong". So the
  staged file overrides any competing option for mei.
- `mkpasswd` is INTERACTIVE by default (`getpass(3)` unless `--stdin`/`--password-fd`): the generator
  must pass the password explicitly (e.g. `mkpasswd --method=yescrypt --stdin <<<"$pw"`).
- The official ISO collision (installation-device sets initialHashedPassword on root/nixos) does NOT
  affect mei, and the flake ISO does not import that profile at all.
- The lifecycle harness exists and covers every case, but is NOT in flake checks.
- Execution (mkpasswd + unshare validator run) was impossible in the lane's sandbox; the lead ran it
  (see the executed-proof section of the synthesis).

## Leads

- L27: password generator must be non-interactive (mkpasswd --stdin) — design detail.
- L28: add the lifecycle harness (+ mutations test) to flake checks — test gap.
- L29: bake the app into the ISO for a no-network install (G6).
