# Wave 1 — lane2 (repo history archaeology) — completed. RELIC: the mechanism already existed.

The lane had no git in its sandbox; it recovered everything through the GitHub API against
meillaya/nixos with `gh api ... --jq '.content|@base64d'`. SHAs match the local checkout.

## Recovered: `bin/nixos-anywhere-bootstrap-password.sh` (final version @ f7015a56, 2026-07-13)

Quoted mechanism (recovered verbatim):
- Requires `XDG_RUNTIME_DIR` on tmpfs; `stage=$(mktemp -d "$runtime/nixos-extra.XXXXXXXX")`.
- `install -d -m 700 "$stage/var/lib/nixos-bootstrap"`; generates the hash via a SHA-pinned
  `nix shell github:NixOS/nixpkgs/$rev#mkpasswd --command mkpasswd --method=yescrypt > $hash_file`;
  `chmod 600 "$hash_file"`.
- Validates: last byte == LF, exactly one line, matches
  `^\$y\$[./A-Za-z0-9]+\$[./A-Za-z0-9]{1,86}\$[./A-Za-z0-9]{43}$`.
- Then `nix run github:nix-community/nixos-anywhere/$rev -- --flake "$flake" --target-host "$target"
  --build-on local --extra-files "$stage" --chown var/lib/nixos-bootstrap 0:0
  --chown home/mei/Pictures 1000:100 --no-substitute-on-destination --option max-jobs 1
  --option cores 1` (final version also staged wallpapers to /home/mei/Pictures/Wallpapers).
- A 3-line fish shim delegated to it.

On-target side (bootstrap-password.nix, same era): `hashedPasswordFile =
/var/lib/nixos-bootstrap/mei-password.hash`; validator before `users`; consumer after `users`
rewrites the file to `!\n`.

## Why it disappeared

No reasoned removal commit: the scripts + their tests vanish at d4f2559 ("Initial NixOS-config",
2026-08-19), the repo-extraction/consolidation import. The design was later re-implemented
target-side (e662f5ab added host-install.sh's install stage; 6992dd25, this session's commit 6992dd2,
made the app the entry point) — but the password-staging half was never rebuilt: the current tree
has ZERO references to `mei-password.hash` / `mkpasswd` / password staging in bin/, apps/, scripts/.

## Orphan test + ISO coverage (lead L3)

- `tests/bootstrap-password-config-eval.nix` was consumed by the DELETED
  `tests/bootstrap-password-mutations.sh` (recovered: it imports the config-eval with
  `{ config = f.nixosConfigurations.x86_64-linux.config; }` and jq-asserts userDeps/consumerDeps).
  It was never wired into flake checks.
- The `hardware-enroll` oneshot has NEVER had a test (commit 57df86dd touched only
  dendritic-architecture.sh); the sole ISO evidence artifact says `"not_built": true`.

## Prior research + gate reviews (recoverable at d4f2559)

- `.omo/ulw-research/20260711-124332-default-nixos-password/SYNTHESIS.md` — the origin of the design:
  "a UNIQUE password per installation, represented as an interactively generated yescrypt hash,
  delivered by nixos-anywhere --extra-files to a root-only persistent file". It REFUTED the /run
  staging alternative.
- `.omo/evidence/default-nixos-password-gate-review.md` — REJECT (validator did not reject every
  file symlink; it tests `-e` before `-L`).
- `.omo/evidence/bootstrap-password-gate-review.md` — REJECT (9 blockers).
- `.omo/evidence/bootstrap-password-final-gate-review.md` — APPROVE (blockers cleared).

## Synthesis implications

1. The password mechanism is not new work: it is a RESTORE of a design this repo shipped and lost in
   a merge. The design should re-use its exact shape (mkpasswd yescrypt + extra-files staging +
   chown 0:0 + activation consumption) and re-add its tests.
2. The known failure modes from the gate reviews (symlink hole) must be re-checked against the
   current module.
3. ISO autostart still has no test coverage; the design should add it (lane1).
