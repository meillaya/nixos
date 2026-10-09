# zix - config and profile management for this repo

## What it is

`zix` is the CLI this repo uses to manage packages, version pins, sandboxes
and VMs without hand-editing Nix. It is deliberately generic - everything
repo-specific lives in `/zix.json`, so the same tool can be pointed at other
configurations (`--repo PATH`, or `ZIX_REPO`). The reference for its commands
is `tools/zix/README.md`; this note records how it is wired into this repo and
why.

Inspiration: Zena Linux's zix (a declarative/imperative Nix *profile*
manager). This zix keeps the idea - JSON manifest, generated outputs,
idempotent commands - but targets a whole dendritic config: curated package
lists, nixpkgs-multiverse version pins, the omniflake index, nix-auto-follow,
rewindvm, omnibin, wrap-buddy and grail, plus the repo's own checks and
switch commands.

## Where it is wired in

| what | where | notes |
| ---- | ----- | ----- |
| CLI | `tools/zix/` (installed as `zix`; `nix run .#zix`) | Python 3 stdlib only; own flake + package, built by `modules/flake/packages.nix` |
| manifest | `zix.json` | targets, tools, switches, checks, sandbox defaults |
| managed state | `zix/managed/` | `manifest.json` canonical; `packages.nix` + `pins.json` generated |
| managed packages | imported by `modules/shared/packages.nix` | reaches every host |
| pins overlay | `lib/nixpkgs.nix` (`zixPins`) | `inputs.multiverse.lib.pinOverlay`; applies via `mkPkgs` everywhere |
| marker blocks | `modules/*/packages.nix` | `# BEGIN zix` / `# END zix`; created on first use |
| check | `tests/zix.sh` (+ `checks.nix`) | unit + fixture tests offline; dry-run smoke against this repo |
| dev shell | `modules/flake/dev-shells.nix` | `zix` function runs the working tree copy |

## Design decisions (and why)

- **Pins live in the policy layer, not a module.** Every host's `pkgs` comes
  from `mkPkgs`, including the standalone Home Manager (see
  `modules/aspects/schema.nix`, `config.pkgs`). An overlay there survives
  `home-manager.useGlobalPkgs = true`, where per-HM `nixpkgs.*` settings are
  silently discarded. This is also why the old "no overlays" policy was
  removed: the pin overlay is the mechanism.
- **The manifest is canonical, generated files are disposable.**
  `zix/managed/manifest.json` records managed packages and pins; the two
  generated files are rewritten from it by every managed change (`zix add`,
  `zix rm`, `zix unpin`), so a hand edit there is undone by the next one.
- **Marker blocks, not format guessing.** Editing arbitrary Nix lists by
  parsing them is fragile; a marker block is an explicit, reviewable
  contract. Removal of whole lines is safe even *outside* the markers
  (`zix rm`), because only `name`-alone-on-a-line matches.
- **Fail closed.** Every mutation snapshots first and restores on any failure
  (parse check, lock, verification mismatch). Pin operations verify by
  evaluating `pkgs.<attr>.version` through the real policy and roll back on
  mismatch.
- **Tools are not re-implemented.** multiverse, omniflake, auto-follow,
  rewindvm, omnibin, wrap-buddy and grail are invoked through their own
  flake entry points (configurable refs in `zix.json`), so zix gains features
  as they release them.

## Companion inputs

`zix` adds the `multiverse` input to `flake.nix` when the first pin is
created (and `nix flake lock` runs then). No other tool needs an input:
omniflake, rewindvm, omnibin, wrap-buddy, grail and nix-auto-follow are all
reachable ad-hoc through `nix run`, which is also how zix wraps them.

## Status and roadmap

v0.1.0, 2026-10-02. Verified end to end:

- 17 unit/fixture tests, offline (`bash tests/zix.sh`; also a `nix flake check`
  derivation), plus dry-run smoke checks against this repo.
- `nix run .#zix -- pkg add hello@2.10` pinned the old version; evaluating the
  real policy returned `pkgs.hello.version == "2.10"` where plain nixpkgs gives
  `2.12.3`. A deliberately broken verification expression rolled every touched
  file back from the snapshot before the fix landed.
- `pkg update --apply` moved the pin 2.10 -> 2.12.3 with verification;
  `pkg rm` removed pin and declaration in one step.

The `multiverse` input was added to `flake.nix` by the first pin and is kept:
pins need it, and everything else zix exposes is reachable ad-hoc. Roadmap in
`tools/zix/README.md` (per-host pins, plain-add attribute validation,
machine0/Modal sandboxes).


## Update (2026-10-07): runtime installs, F2, and the machine0 integration

zix grew the piece agents use most: `zix get NAME[@VERSION]` installs into the
invoking user's nix profile, needs no repository, and resolves through
nixpkgs-multiverse's store-path index (no nixpkgs evaluation; it falls back to
the evaluating road when the index has no match, and says so). Alongside it:

- `get` is repo-optional (cli.py REPO_OPTIONAL); everything else may fall back
  to a system manifest at `/etc/zix/zix.json` (`ZIX_SYSTEM_CONFIG`) when no
  `zix.json` is found upwards - that is what images ship so `zix get` works
  with no checkout on disk.
- The critical review's F2 is fixed: `pkg where` scans `modules/**` for
  `pkgs.<name>` declarations and reports them as `aspect` hits (`pkg rm`
  refuses to edit those by hand; `pkg add` stops planning duplicates).
- New manifest keys for multi-repo use: `default_target`, `no_pins`,
  `runtime_only` (doctor honours the last one).
- Version 0.2.0; 25 offline tests plus the smoke checks (`bash tests/zix.sh`,
  also a `nix flake check` derivation), all green.

machine0 (/home/mei/machine0) now integrates the CLI: `tools/zix` (vendored
mirror), `pkgs/zix` (python3 + wrapper), `m0coding.zix.enable` (default on)
installs it and seeds `/etc/zix/zix.json`, `~/.nix-profile/bin` is on the nix
user's path, and image packages are managed declaratively through
`modules/packages.nix` (`nix run .#zix -- pkg add NAME`; default_target=image,
no_pins=true - exact versions go through `zix get`). Verified there:
`nix flake check` clean, `nix build .#zix`, `doctor` all ok, add/rm round trip
on `modules/packages.nix`, and `zix get hello@2.10` installing GNU Hello 2.10
from an empty directory.


## Update (2026-10-08): zix becomes its own program

The CLI no longer runs from a wrapper over this checkout. It is built by
`tools/zix/package.nix`, which ships code only and records no repository path,
and `tools/zix/flake.nix` exposes that same derivation as `packages.default`
and `apps.default`. It therefore runs without this repository:

    nix run github:meillaya/nixos?dir=tools/zix -- --help

Every host installs it through `modules/shared/packages.nix`, so `zix` is on
PATH after a switch, and `nix run .#zix` points at the same derivation rather
than a second implementation.

The package verbs gained bare aliases: `zix add` is `zix pkg add`. One
registration function produces both, so the surfaces cannot drift. `update`
stays the flake-input refresh at the top level while `zix pkg update` moves
pins.

The marker text written into package lists changed with it: the line is now
`# BEGIN zix: entries managed by `zix add` / `zix rm``. Matching uses the stable
`# BEGIN zix:` prefix, so a block written by an earlier release is still found
and never duplicated; a test covers that.
