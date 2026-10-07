---
slug: thinkpad-zero-touch-install
status: reviewed-approved
intent: clear
review_required: true
plan_path: .omo/plans/thinkpad-zero-touch-install.md
plan_sha256: 62ae22cdc559cf4905e77d60408ec17a2b9af1d719763d9da19531815e2c89db
review_round_id: round-3
review_round_limit: 5
pending-action: none - plan approved (round 3 OKAY; 3 nits reconciled). Execution starts separately via /ulw-execute.
review:
  plan_reviewer:
    status: pending
    workspace_root: null
    runtime_home: null
    target: .omo/plans/thinkpad-zero-touch-install.md
    round_id: null
    plan_sha256: null
    launch_id: null
    session: null
    result: null
approach: Restore the lost password caller in the install path and stage the password + enrollment artifacts + the age identity into the installed system through nixos-anywhere `--extra-files` (no second USB), add the ISO's missing btrfs/vfat support and the missing /etc/hardware-enrollment mkdir, and add an OPT-IN gated autostart unit (a plain ISO boot stays inert). No new installer project; auto-install is optional and test-covered.
---

# Draft: thinkpad-zero-touch-install

## Affected user and ideal state

Users: (1) the operator installing the ThinkPad; (2) the installed machine's first boot (activation, HM github-key
activation, sops identity); (3) the repo's maintainers and CI (tests/docs); (4) the machine-authority records.

- IS-1 | `mei` has a working, per-install password the operator saw once at install time | the machine is loggable
  with no console gymnastics after the reboot.
- IS-2 | Enrollment artifacts and the age identity persist on the installed system itself | no second USB, no
  external medium, nothing to lose in RAM.
- IS-3 | The irreversible item (the &workstation age identity) survives the disk wipe by construction | losing it
  would lock `secrets/github-ssh.yaml` forever.
- IS-4 | A plain boot of the installer ISO touches nothing; the install runs only behind an explicit opt-in |
  an accidental boot must never wipe a machine.
- IS-5 | The trust boundary is intact: `--yes`, the live-root guard, the reviewed enrollment; the autostart path
  adds a host/disk match and a completion marker | the automation must not weaken the gates.
- IS-6 | Docs and tests reflect the new behavior; ISO autostart is covered | today it has zero coverage.
- IS-7 | One install medium (the flake ISO) and one entry point (the app) | no second install path to maintain.

- GAP-1 | No caller writes /var/lib/nixos-bootstrap/mei-password.hash; the validator fails on a fresh install |
  the caller was lost in the d4f2559 merge | todo 1-3.
- GAP-2 | Artifacts persist only via `--save` to external media (the work tree is RAM) | no in-target staging |
  todo 4-6.
- GAP-3 | The age identity lives only on the disk being wiped | nothing copies it off first | todo 5, 8.
- GAP-4 | Nothing runs the install automatically; when added it must stay opt-in | user constraint + wipe risk |
  todo 9-11.
- GAP-5 | iso.antagony lacks btrfs/vfat support, btrfs-progs, and a boot-loaded btrfs module | pending host
  declares no filesystems | todo 7-8, 12.
- GAP-6 | iso-images.nix writes /etc/hardware-enrollment/<host>.json without creating the directory, masked by
  `|| true` | the ISO's enrollment has likely never run | todo 7.
- GAP-7 | ISO autostart and the staging path have zero test coverage | no VM/eval assertions exist | todo 12-14.

## Components (topology ledger)

| id | outcome (one line) | status | evidence path |
|---|---|---|---|
| C1 | The install path generates and stages a per-install yescrypt password hash | active | tests + staged transcript |
| C2 | The transport (`--extra-files`) is wired through both the app and host-install.sh | active | grep/eval test |
| C3 | Enrollment artifacts + the age identity land in the installed system (no USB) | active | staged tree listing |
| C4 | ISO support: btrfs/vfat + kernelModules + the hardware-enrollment mkdir fix | active | iso eval wall |
| C5 | Optional gated autostart (inert on a plain boot) | active | VM test + eval wall |
| C6 | Tests and docs cover the new behavior | active | check suite green |

## Open assumptions (announced defaults)

| assumption | adopted default | rationale | reversible? |
|---|---|---|---|
| chown for the bootstrap dir | no `--chown var/lib/nixos-bootstrap` | extraction already yields root:root; less blast radius | yes |
| where the age identity lands | both /var/lib/nixos-enrollment/ (0700 root) and home/<user>/.config/sops/age/keys.txt (0600, chowned 1000:100) | retrievable and usable by first-boot HM | yes |
| password delivery | printed once to console+journal; never written plaintext to disk | avoids a plaintext secret on disk | yes |
| staging dir location | the app's existing private staging area, removed after the run | no leftover secrets | yes |
| autostart gate | kernel cmdline `nixos.autoinstall=1` only; no grub.cfg patching; docs explain editing the entry | brittle grub patching avoided | yes |
| old-disk identity rescue | explicit `--rescue-identity` flag (mount `subvol=@home` ro, copy, unmount), never automatic; must follow the LIVE subvolume names (`@`, `@home`, `@root`, `@srv`, `@cache`, `@log`, `@tmp`), not disk-config's (`@root`/`@home`/`@nix`/`@log`) | destructive-adjacent step stays opt-in; disk-config names differ from the live layout | yes |

## Findings (cited - path:lines)

- Password staging is absent end to end: `apps/x86_64-linux/install:327-332` invokes host-install.sh with no files payload, and `bin/host-install.sh:201` runs nixos-anywhere with no `--extra-files`. Insertion points: app var block after `:38`, help after `:55-57`, parser arm beside `:100-105`, a staging step after the final flow's `:358`, forwarded in `install_phase` `:328-332`; host-install.sh var after `:43`, arm before `:85`, command `:201`, dry-run plan `:111`.
- `mkpasswd` is a top-level attr on the pinned nixpkgs (`p.mkpasswd.pname == "mkpasswd"`, lead eval) - wire it into `modules/flake/apps.nix:522-528` (`installDeps`).
- ISO module slots: `modules/flake/iso-images.nix:60` is the `extendModules` list to extend; no `boot.supportedFilesystems`/`boot.kernelModules` exists in that file today, so both go inside the new module. Latent bug at `:44`: writes `/etc/hardware-enrollment/<host>.json` with only `/root/enroll` (`:43`) created.
- Test coupling: `tests/dendritic-apps.sh:27-29` (dry-run plan greps - a new plan line needs a grep), `:20` and `:41-52` (app inventory); `tests/dendritic-config-eval.nix:13-15,146` (app set), `:232` (hashedPasswordFile pin); `tests/bootstrap-password-{config-eval,lifecycle,secret-scan}` (the contract suites); `tests/dendritic-architecture.sh:49` (feature file must keep existing); a new check follows `modules/flake/checks.nix:5-15`.
- Rescue layout correction (grounding lane): the live laptop mounts `/` from subvolume `@` and `/home` from `@home` (plus `@root`->/root, `@srv`, `@cache`, `@log`, `@tmp`); `modules/nixos/disk-config.nix:68-84` names the target root subvolume `@root` and mounts `@root` at `/root`. A rescue mount must follow the LIVE layout (`@`, `@home`, `@root`, ...), never disk-config's names, or it mounts the wrong subvolume.
- Antagony receives the bootstrap-password contract via `named-hosts/antagony.nix:11` -> `storage/antagony.nix:14-22` -> `pending|enrolled-x86-workstation-hardware` -> `roles/workstation-linux.nix:5` -> `features/bootstrap-password.nix:3-5` -> `modules/nixos/bootstrap-password.nix:9-12` (mutableUsers, hashedPasswordFile, the failing validator). That is why the missing staging step is a hard blocker on fresh installs.
- `inputs.self` is the flake source the app already uses (`modules/flake/apps.nix:3,19`); `iso-images.nix` takes only `{ lib, config, ... }`, so the plan must add `inputs` to its args for the baked-flake path (lead check).
- `pkgs.mkpasswd` resolves on the pinned nixpkgs (lead eval: `p.mkpasswd.pname == "mkpasswd"`), so `installDeps` can carry it directly.

## Decisions (with rationale)

- D1 | Restore the historical password caller rather than invent new machinery | the mechanism shipped at f7015a56 and was lost in d4f2559; its tests and gate reviews exist.
- D2 | Stage into the installed system via `--extra-files` | proven modes/ownership; removes the second-USB requirement.
- D3 | Preserve the age identity; treat the sops store as optional | nothing declares sops.secrets; gen_trust needs no store; the identity is the irreversible item.
- D4 | Auto-install is OPTIONAL, gated, and inert by default | the user's explicit constraint; the disko path wipes without its own prompt.
- D5 | No new installer project | the flake ISO already is the custom installer; community consensus agrees.
- D6 | Keep `--save` as an escape hatch | operator flexibility; no longer a requirement.

## Scope IN

- Password staging (generator + validator + `--extra-files`) and the transport wiring.
- Enrollment-artifact and age-identity staging into the installed system.
- ISO additions (btrfs/vfat, kernelModules, enrollment mkdir fix).
- Optional gated autostart with host/disk match + completion marker.
- Tests (staging invariants, ISO eval wall, VM gate-inertness) and docs.

## Scope OUT (Must NOT have)

- Never bake `nixos.autoinstall=1` into `boot.kernelParams`; never make autostart the default path.
- No plaintext password written to disk or to the nix store.
- No new installer project; no grub.cfg patching; no second install path.
- No weakening of `--yes`, the live-root guard, or the reviewed-enrollment boundary.
- No `--chown -R` over a user's whole home; only the staged subtrees.
- No changes to unrelated aspects (containers, desktop, etc.).

## Open questions

- None: the user already gave the one owner-decision ("keep auto-install optional"). Everything else is a reversible
  internal default recorded above for veto at the gate.

## Proposed plan outline (refined after the architect advisory)

Commit boundaries (atomic, in this order): 1 `fix(iso)` mkdir; 2 `feat(iso)` btrfs/vfat/kernelModules; 3 `feat(install)` shared staging builder `bin/_install-staging.sh`; 4 `feat(install)` `--extra-files` pass-through in host-install.sh; 5 `feat(install)` app composition (password + artifacts + identity); 6 `feat(iso)` bake the flake + the gated unit; 7 `test(install)` wire checks; 8 `docs(install)`.

| # | task | category | acceptance (one line) |
|---|---|---|---|
| 1 | `fix(iso)`: create `/etc/hardware-enrollment` before the base-record write (`iso-images.nix:43-44`) | quick | the composed unit script orders mkdir before the write; eval builds |
| 2 | `feat(iso)`: `boot.supportedFilesystems = [ "btrfs" "vfat" ]` + `boot.kernelModules = [ "btrfs" ]` in a new ISO module added at `iso-images.nix:60` | deep-low | re-run VA2: btrfs/vfat present, `btrfs-progs` in `system.fsPackages` |
| 3 | `feat(install)`: shared staging builder `bin/_install-staging.sh` (dir 0700/file 0600/owner, one LF, regex; mkpasswd from the repo's own lock; tmpfs only; no callers yet) | deep-low | `tests/install-staging.sh` passes; feeding its output through the validator recipe returns rc=0 |
| 4 | `feat(install)`: `host-install.sh --extra-files DIR` pass-through (args, usage, `print_plan:111`, forward at `:201`); first-ever host-install test | deep-low | `--dry-run` shows the flag; the command carries it when set |
| 5 | `feat(install)`: the app composes the tree AFTER `enroll()`: password hash, `var/lib/nixos-enrollment/{candidate,intake,host-key}`, `home/<user>/.config/sops/age/keys.txt` when the identity exists (chown `home/<user>/.config 1000:100`), forwards `--extra-files` at `:328-332`; `want_save` no longer forces `--save` when the key was staged; password also written 0600 to `/run` (tmpfs) | deep-low | staged tree listing + `--dry-run` shows the new step; `dendritic-apps.sh:27-29` substrings survive |
| 6 | `feat(iso)`: bake the flake (`inputs` must be added to the module args: currently `{ lib, config, ... }`; reference it as `${inputs.self}`, the repo's convention per `apps.nix:3` and `checks.nix:9`) + the gated unit (`ConditionKernelCommandLine = "nixos.autoinstall=1"`, `Wants/After network-online.target`, `After sshd.service hardware-enroll.service`, oneshot, `OnFailure = iso-install-rescue.target`, journal+console) invoking `nix run ${inputs.self}#install -- --yes`; upstream's own reboot owns the lifecycle (no `--no-reboot` threading); keep `|| true` on the oneshot + add a journal marker | unspecified-high | eval wall pins the unit fields and the NEGATIVE assertion (flag NOT in `boot.kernelParams`); inertness VM passes |
| 7 | `test(install)`: extend `dendritic-apps.sh`; add `tests/install-staging.sh` + wire in `checks.nix`; ISO eval wall in `dendritic-config-eval.nix`; re-add `tests/bootstrap-password-mutations.sh` (un-orphan the config-eval); probe `unshare` viability in the check sandbox first | unspecified-low | the check suite is green; each new check fails when its invariant is broken |
| 8 | `docs(install)`: README + service notes + `bin/AGENTS.md` (optional autostart gate, the new flags, the rescue route, official-ISO residue) | writing | docs match the shipped flags; no doc-text assertions exist to update |
| F1..F3 | Final verification wave: full repo suite + `nix flake check --all-systems --no-build`; the executed validator proof; the ISO eval wall | unspecified-high | every command exit 0 plus the proof transcript |

VM-test split (architect): the cheap gate assertions (unit present; inert without the flag) belong in the default checks; the full `=1` install run is deliberately executed, not wired into `nix flake check`.

Rollback notes (every irreversible step): the identity copy must happen before nixos-anywhere runs and stays in tmpfs until the app exits; never delete `mei-password.hash` to reset (the sentinel needs an unlocked shadow password); reverting the unit requires re-flashing media; the fold stays revertible via git history; staged trees must never be committed (tmpfs, 0700).

## Pinned contracts (ultrabrain advisory - adopted)

- Staging tree: `$stage/var/lib/nixos-bootstrap/<user>-password.hash` (0600 in 0700, root:root, no `--chown`); `$stage/var/lib/nixos-enrollment/{<host>.json,<host>.intake.json,<host>.host-key,age-keys.txt}` (0600 in 0700, root:root); `$stage/home/<user>/.config/sops/age/keys.txt` (0600) with `--chown home/<user>/.config <uid>:<gid>` ONLY (the pinned users activation chowns/chmods $HOME itself at first boot).
- Password pipeline: `pw="$(head -c 512 /dev/urandom | base64 -w0 | tr -dc 'A-Za-z0-9' | cut -c1-24)"` (pipefail-safe); `hash="$(printf '%s\n' "$pw" | mkpasswd --method=yescrypt --stdin)"`; validate against the module regex before writing; write 0600 in 0700; self-check `stat` 0:0:700/0:0:600; print exactly once; `unset pw`.
- Unit runs **the wrapper**: `${config.flake.apps.x86_64-linux.install.program} --host <host> --yes --rescue-identity` (the wrapper carries the PATH deps and executes the source-store script, so `path:` flake resolution works offline); never `nix run github:...`, never the raw script.
- Rescue target: `OnFailure = [ "iso-install-rescue.target" ]` plus a 6-line debug service (`bash -i` on tty1) because sulogin credentials on this ISO are unverified.
- Enrollment fix: prefer `environment.etc."hardware-enrollment/<host>.json".text = baseDeclaration;` (removes the mkdir failure mode, eval-testable); keep the runtime `printf` only as a fallback with `install -d`.
- Re-run guard (downgraded from a persistent marker): per-boot cmdline flag + the unit exists only in the ISO closure + `/run/autoinstall-done` written by `host-install.sh stage_install` immediately before the nixos-anywhere call (a failure before it leaves no marker; a retry after it needs an explicit `rm`). No ESP marker.
- Host/disk match in `verify_host_match()` between `enroll()` and the fold/build: Phase P (pending record) = DMI must map to `--host`, else die with no override; Phase E (enrolled) = candidate vs baked record equality on `storage.diskById`, `storage.expected.{sizeBytes,logicalSectorBytes,modelSha256,serialSha256}`, `cpuVendor`.
- Test assertions (exact): the ISO eval wall (needs `flake.isoConfig` exposed from `iso-images.nix`) asserts supportedFilesystems/kernelModules, the NEGATIVE kernelParams check, the unit's wantedBy/after/wants/condition/SuccessAction/OnFailure/Type/RemainAfterExit/StandardOutput, the script containing `install`+`--rescue-identity`, `variant_id == "installer"`, and the etc enrollment JSON; `tests/install-staging.sh` asserts the mkpasswd/`--extra-files`/`--chown`/paths/regex/modes/`unset pw`/print-once/dry-run-no-secret invariants; do NOT wire `tests/bootstrap-password-lifecycle.sh` into `checks.nix` (bind mounts + sandbox; destructive-risk doc) - the static grep test is the check-safe coverage.

## Approval gate
status: awaiting-approval
<!-- When exploration is exhausted and unknowns are answered, set status: awaiting-approval. -->
<!-- That durable record is the loop guard: on a later turn read it and resume at the gate instead of re-running exploration. -->
