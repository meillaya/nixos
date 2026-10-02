# fzakaria tooling review (October 2, 2026)

## Purpose

Review of https://fzakaria.com/ (Farid Zakaria) for this repo: which projects
could earn a place in the config or the operator workflow, and which are
consult-only. Claims below were checked on 2026-10-02 against the live
repositories; where a tool was run, the run is stated.

Update, same day: the follow-up work landed - the no-overlay policy was
removed and `zix` was built (docs/service-notes/zix.md, `nix run .#zix`) as
the single entry point for multiverse pins, omniflake, nix-auto-follow,
rewindvm, omnibin, wrap-buddy and grail. The sections below still describe
what each tool is and what it was verified to do.

## Act on

### nixpkgs-multiverse — any version of any package, from one flake input

- Index at review time: 314,472 package versions across 32,350 attributes from
  1,562 revisions (2012-07-05 .. 2026-10-01). The flake declares no nixpkgs
  inputs; revisions load lazily via builtins.fetchTree, so only revisions
  actually touched cost anything.
- Verified runs:
  - `nix run github:fzakaria/nixpkgs-multiverse#mvs -- query versions hello`
    listed every hello version ever shipped (2.7 through 2.12.3).
  - `nix build ...#fast.latest.hello.out` substituted hello-2.12.3 straight
    from cache.nixos.org; the fast path skips evaluation entirely.
- Fit: extends `nix run .#search-pkgs` (stable + unstable only) to the whole
  history, and replaces the "add another nixpkgs pin" reflex when a package
  version regresses (see the paused freecad/boost entry in
  `modules/linux/packages.nix`).
- Recommendation: operator tool (`nix run` / `mvs`) first. A nixos / darwin /
  home-manager module exists (`multiverse.pins.<attr> = "<version>"`) if
  version pinning ever becomes policy; not a core flake input today.

### nix-auto-follow — follows hygiene

- Ran `nix run github:fzakaria/nix-auto-follow -- -c` against this flake.lock
  on 2026-10-02. Result: one dedupe opportunity — `deploy-rs` and `helium`
  each carry their own `flake-compat` node (`flake-compat` / `flake-compat_2`).
- To unify: add a top-level `flake-compat.url = "github:edolstra/flake-compat"`
  input and chain `follows` through both consumers, then re-lock; or accept
  the extra node.
- Candidate for the update flow or a cheap check (`-c` exits 1 when the lock
  cannot be deduped).

## Trial (no config change yet)

### rewindvm — deterministic KVM VMs for flaky builds and tests

- Records a run (Nix build, test suite, any command) inside a KVM VM whose
  execution is a pure function of its inputs; scrub, replay, and fork a run
  with a different thread interleaving. Engine and CLI are MIT; the desktop
  app is proprietary (Lunch Time Surf LLC).
- `/dev/kvm` is present on the standalone host, so it is runnable here:
  `nix run github:fzakaria/rewindvm` (x86_64-linux only; on AMD run
  `rewind pmu enable` once per boot for exact time).
- Candidate for chasing flaky tests (e.g. malina) and odd `nix flake check`
  failures.

### omnibin — every binary nixpkgs ever shipped, on PATH (FUSE)

- 51,469 binaries (884,918 name@version forms) on x86_64-linux; a lazy FUSE
  view over /nix/store; nothing is fetched until a file is read.
- Three entry points: a shell (`nix run github:fzakaria/omnibin`), a NixOS
  module (`services.omnibin.enable`), and a container (`fmzakari/omnibin`,
  needs /dev/fuse + SYS_ADMIN).
- Strongest fit is agent sandboxes that must not guess their toolchain
  (m0-coding / Modal image work); not for the daily driver.

### wrap-buddy — prebuilt ELF binaries on NixOS

- Mic92's tool; the fzakaria post is the explainer. Patches the entry point
  with a stub loader instead of rewriting ELF headers, for binaries where
  autoPatchelfHook fails. Not in the pinned nixpkgs (checked 2026-10-02):
  `github:Mic92/wrap-buddy`.
- Relevant when the NixOS hosts activate and curl-installed agent tooling
  meets them; the CachyOS host has a host glibc and does not need it.

## Consult-only

- omniflake (17,020 flakes behind one input): reachable without touching the
  config via `zix flakes list` / `zix flakes run <name>`; still not a core
  input (the trust in its index pinning stays a deliberate opt-in).
- trynix and the `fzakaria/trynix@v1` PR-preview action: boot a package or a
  PR build in a browser tab; useful for trying builds without touching config.
- grail: version-range solver (clingo/ASP) over the multiverse index; a
  pocket tool for "no single revision ever satisfied X together with Y".
- seenix: one-pixel-per-byte maps of Nix closures in the browser.
- sqlelf / selfdb: SQL over ELF objects; executables as SQLite databases.
- guixpkgs / guix-transfer: Guix packages via Nix; no fit for these hosts.
- "A Nix store is three functions": GitHub Pages / npm as substituters; fun,
  no operational need.
- "Hiding my AI slop": deterministic banned-words prose check for
  agent-written text; candidate for repos that publish prose, not this one.
