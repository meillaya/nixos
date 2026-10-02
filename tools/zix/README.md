# zix

Config and profile manager for this Nix configuration (and, once mature, for
any repo that ships a `zix.json`). It streamlines the operations that were
multi-file, multi-tool dances before:

- add / remove packages across the curated lists, idempotently
- pin any package to any version nixpkgs ever shipped (nixpkgs-multiverse),
  verify the pin by evaluation, and roll back automatically on failure
- search all of nixpkgs history, run flakes from the omniflake index without
  adding inputs, audit `follows` with nix-auto-follow
- disposable agent sandboxes (omnibin image), disposable VMs (rewindvm),
  omnibin / wrap-buddy / grail passthroughs
- run the repo's check suite, switch a host, refresh inputs

Everything is repo-aware: file edits are parse-checked, snapshotted, and
rolled back if anything fails. All mutations support `--dry-run`.

    nix run .#zix -- --help
    nix run .#zix -- doctor

From a checkout you can also run it directly (no flake evaluation):

    python3 tools/zix/cli.py --help

## Command map

| area        | commands |
| ----------- | -------- |
| packages    | `pkg add NAME[@VERSION] [--target T]`, `pkg rm NAME`, `pkg unpin NAME`, `pkg list`, `pkg where NAME`, `pkg update [--apply]` |
| search      | `pkg search QUERY` (nixpkgs stable+unstable), `pkg versions NAME` (every version ever, via `mvs`) |
| flakes      | `flakes list [--match S]`, `flakes run NAME [--attr A] [--pinned]` (omniflake) |
| inputs      | `input ls`, `input add NAME --url URL [--follows p=n]`, `input remove NAME` |
| follows     | `follows check` (exit 1 when the lock is not deduped), `follows fix` (in-place, backed up) |
| sandboxes   | `sandbox run [--agent claude] [--image I] [-- CMD]`, `sandbox ls`, `sandbox exec [NAME]`, `sandbox rm [NAME|--all]` |
| VMs         | `vm ...` - verbatim passthrough to rewindvm (`vm check`, `vm run`, `vm replay`, ...) |
| other tools | `bin ...` (omnibin), `wrap ...` (wrap-buddy), `grail ...` |
| repo glue   | `doctor`, `check [--full]`, `switch [HOST]`, `update` |

Global flags: `--repo PATH`, `--dry-run`, `--json`, `--no-color`, `-q`.

## Where state lives

`zix.json` (repo root) is the manifest of manifests: it names the package
targets, the companion tools (flake refs + command prefixes), the switch
commands, the check suite, sandbox defaults, and the pins policy file.

Command prefixes (`switches.*`, `update_command`, `tools.*.command`) are argv
arrays whose extra CLI arguments are appended verbatim; end a prefix with
`--` when it wraps `nix run`, so zix's arguments reach the app rather than nix.

    zix.json                     # the zix manifest (hand-kept)
    zix/managed/manifest.json    # source of truth: managed packages + pins
    zix/managed/packages.nix     # generated, imported by modules/shared/packages.nix
    zix/managed/pins.json        # generated, read by the pin overlay in lib/nixpkgs.nix
    zix/backups/                 # pre-change snapshots (gitignored)

Curated lists (`modules/*/packages.nix`) are edited through marker blocks:

    ++ [
      # BEGIN zix: entries managed by `nix run .#zix -- pkg ...` - do not edit by hand
      htop
      # END zix
    ]

zix creates the block on first use. Insertion only writes a bare line inside
the block; removal matches whole lines only (`htop` or `pkgs.htop` alone on a
line), so expressions and one-liners are never touched.

## How pinning works

`zix pkg add python3@3.8.9`:

1. resolves the version against the nixpkgs-multiverse index (`mvs`), refusing
   versions that never shipped (and listing recent ones),
2. ensures the `multiverse` flake input exists and re-locks if it added it,
3. writes the pin to `zix/managed/pins.json` (plus the package itself to a
   target if it was not yet declared anywhere),
4. verifies by evaluating `pkgs.python3.version` through the real policy -
   a mismatch rolls every touched file back from the snapshot.

The overlay applying the pins lives in `lib/nixpkgs.nix`
(`inputs.multiverse.lib.pinOverlay`). That layer is deliberate: every host's
package set comes from `mkPkgs`, which survives home-manager's
`useGlobalPkgs = true`, so one pin reaches NixOS, nix-darwin and the
standalone Home Manager alike.

`zix pkg update` reports how far each pin is behind the latest version;
`--apply` moves them (verifying each). `zix pkg unpin` returns a package to
following nixpkgs.

## Safety model

- Every mutating operation takes a snapshot into `zix/backups/` first; on any
  failure (parse check, `nix flake lock`, pin verification) the snapshot is
  restored and the command exits non-zero.
- Text edits are validated with `nix-instantiate --parse` before anything else
  runs.
- `--dry-run` prints the intended diffs and skips state-changing commands.
- Idempotency is a rule: adding a declared package, removing an absent one, or
  re-pinning the same version are no-ops with an explanation.

## Tools this wraps

Configured in `zix.json` under `tools.*` (change the flake refs there to pin
them, e.g. `github:fzakaria/omnibin/<rev>`):

| tool | what zix offers |
| ---- | --------------- |
| nixpkgs-multiverse | version resolution (`pkg versions`, pin checks) + pins via `pinOverlay` |
| omniflake | `flakes list` / `flakes run` - run any indexed flake, no input needed |
| nix-auto-follow | `follows check` / `follows fix` |
| rewindvm | `vm ...` - deterministic disposable VMs (`/dev/kvm` required) |
| omnibin | `bin ...` - interactive shell or one-off command with every binary ever shipped |
| wrap-buddy | `wrap ...` - patch a stubborn prebuilt ELF for NixOS |
| grail | `grail solve '...'` - version-range queries |

## Extending to other repos

Ship a `zix.json` with the same schema (see this repo's as the reference
implementation) and the tool works unchanged: targets point at that repo's
package files, `switches` at its activation commands, `checks` at its test
suite. Nothing is hardcoded to this configuration; discovery is a walk up
from the current directory for the nearest `zix.json`.

## Limits / roadmap

- Version existence checks need network (the multiverse index); `--skip-check`
  works offline.
- Pins are global (all hosts, all systems). Per-host pins need a plan.
- `pkg add` does not yet validate that the attribute exists in nixpkgs for
  plain (unpinned) adds; the build catches typos.
- `sandbox` is local-only (podman/docker). Machine0 / Modal integration is a
  later stage.
- The check suite in `zix.json` runs what the repo's tests/README lists; keep
  the two in sync when adding checks.
