# zix

Config and profile manager for Nix configurations. It streamlines the
operations that were multi-file, multi-tool dances before:

- add / remove packages across a repo's curated lists, idempotently
- pin any package to any version nixpkgs ever shipped (nixpkgs-multiverse),
  verify the pin by evaluation, and roll back automatically on failure
- search all of nixpkgs history, run flakes from the omniflake index without
  adding inputs, audit `follows` with nix-auto-follow
- disposable agent sandboxes (omnibin image), disposable VMs (rewindvm),
  omnibin / wrap-buddy / grail passthroughs
- run a repo's check suite, switch a host, refresh inputs

zix is a program rather than a directory inside someone's dotfiles. No
configuration is compiled into it: the CLI walks up from the working directory
for the nearest `zix.json` (or takes `--repo`), and that manifest names the
package lists, switch commands, check suite and tools. Point it at any repo
that ships one.

## Install

    nix run github:meillaya/nixos?dir=tools/zix -- --help       # run it
    nix profile install github:meillaya/nixos?dir=tools/zix     # keep it

Every host in this configuration installs the same derivation, so after a
switch the CLI is on PATH:

    zix doctor
    zix add ripgrep

From a checkout, with no flake evaluation:

    python3 tools/zix/cli.py --help

The derivation is `package.nix`; the standalone flake is `flake.nix`. Both the
hosts and the flake build that one expression, so every entry point runs the
same code.

Everything is repo-aware: file edits are parse-checked, snapshotted, and
rolled back if anything fails. All mutations support `--dry-run`.

## Command map

| area        | commands |
| ----------- | -------- |
| runtime     | `get NAME[@VERSION] [--profile P] [--force] [--eval-road]`, `get --list` - install now; no repo needed |
| packages    | `add NAME[@VERSION] [--target T]`, `rm NAME`, `unpin NAME`, `list` (alias `ls`), `where NAME`, `pkg update [--apply]` |
| search      | `search QUERY` (nixpkgs stable+unstable), `versions NAME` (every version ever, via `mvs`) |
| flakes      | `flakes list [--match S]`, `flakes run NAME [--attr A] [--pinned]` (omniflake) |
| inputs      | `input ls`, `input add NAME --url URL [--follows p=n]`, `input remove NAME` |
| follows     | `follows check` (exit 1 when the lock is not deduped), `follows fix` (in-place, backed up) |
| sandboxes   | `sandbox run [--agent claude] [--image I] [-- CMD]`, `sandbox ls`, `sandbox exec [NAME]`, `sandbox rm [NAME|--all]` |
| VMs         | `vm ...` - verbatim passthrough to rewindvm (`vm check`, `vm run`, `vm replay`, ...) |
| other tools | `bin ...` (omnibin), `wrap ...` (wrap-buddy), `grail ...` |
| repo glue   | `doctor`, `check [--full]`, `switch [HOST]`, `update` |

Every package and search verb also works under `zix pkg <verb>`, the long form.
`zix update` refreshes flake inputs while `zix pkg update` moves pins.

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
    zix/managed/packages.nix     # generated package list for the repo's hosts
    zix/managed/pins.json        # generated pin registry for the pin overlay
    zix/backups/                 # pre-change snapshots (gitignored)

Curated lists named under `targets` are edited through marker blocks:

    ++ [
      # BEGIN zix: entries managed by `zix add` - do not edit by hand
      htop
      # END zix
    ]

zix creates the block on first use. Insertion only writes a bare line inside
the block; removal matches whole lines only (`htop` or `pkgs.htop` alone on a
line), so expressions and one-liners are never touched.

## How pinning works

`zix add python3@3.8.9`:

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

`zix pkg update` reports how far each pin is behind the latest version and
`--apply` moves them (verifying each); bare `zix update` refreshes flake inputs
instead. `zix unpin` returns a package to following nixpkgs.

## Runtime installs (`zix get`)

`add` edits the repo (the next rebuild installs the package); `get` is the
runtime counterpart - it installs into a nix profile immediately, edits no
repository files, and works with no `zix.json` anywhere:

    zix get ripgrep                 # latest, from the store-path index
    zix get hello@2.10              # a version nixpkgs shipped in 2016
    zix get --list                  # what the profile holds now

Resolution goes through nixpkgs-multiverse's store-path index: every version
nixpkgs ever shipped maps to the store path its build produced, so an exact
version installs without evaluating nixpkgs at all (seconds, a few hundred MB
of peak RAM instead of the eval spike). When the index has no match - unfree,
broken, or newer than the index pin - `get` falls back to the evaluating road
and says so. `--eval-road` forces that up front.

Where it installs: the invoking user's profile (`~/.nix-profile`, or
`--profile PATH`). Make sure that profile's `bin` is on PATH - the image
integration does, and plain installs print a warning when the new binary is
not reachable. Installs are idempotent (an existing entry is reported, not
duplicated; `--force` reinstalls).

On machines with no checkout - images, throwaway containers - `zix` reads a
system manifest at `/etc/zix/zix.json` (override: `ZIX_SYSTEM_CONFIG`) when no
`zix.json` is found upwards. Mark such a manifest `"runtime_only": true` and
`doctor` stops expecting package lists, a flake or pins.

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
| nixpkgs-multiverse | version resolution (`versions`, pin checks) + pins via `pinOverlay` |
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
from the current directory for the nearest `zix.json` (then the system
manifest above). Manifest keys that shape multi-repo behaviour:

| key | effect |
| --- | ------ |
| `default_target` | target `add NAME` writes to when `--target` is omitted |
| `no_pins` | refuse version pins (with a pointer at `zix get`) when the repo has no pin policy file |
| `runtime_only` | `doctor` skips repo-shaped probes (package lists, flake input) |

## Limits / roadmap

- Version existence checks need network (the multiverse index); `--skip-check`
  works offline.
- The store-path index does not cover unfree, broken, or post-pin releases;
  those take the evaluating road (or a future upstream pin kind - the critical
  review's F1).
- `get NAME` (no version) resolves the newest version that has a *prebuilt
  store path*, which is not always upstream's newest release (multiverse's own
  example: vscode served 1.104.3 while 1.107.x existed without one). Pin
  `NAME@VERSION` when the difference matters.
- Pins are global (all hosts, all systems). Per-host pins need a plan.
- `add` does not yet validate that the attribute exists in nixpkgs for plain
  (unpinned) adds; the build catches typos.
- `where`/`rm` see hand declarations anywhere in a repo (`pkgs.<name>`) and
  refuse to edit them; whole-line removal elsewhere in a target file still
  applies as documented.
- `sandbox`/`vm` are local-only (podman/docker, /dev/kvm) and cannot run on
  platforms without /dev/fuse or privileged containers (e.g. Railway).
- Global flags must precede the subcommand (F3 in the review); not yet fixed.
- The machine0 integration should consume this flake
  (`github:meillaya/nixos?dir=tools/zix`) instead of vendoring its own copy of
  `tools/zix`; two copies of one tree drift.
