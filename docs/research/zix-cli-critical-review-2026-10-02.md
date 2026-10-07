# zix: CLI review and fzakaria integration analysis

Date: 2026-10-02
Revision reviewed: `58b9c78` (clean tree; the feature landed in `3491ca0`)
Status: critical review — strengths, limits, and a worked failure case

Bias disclosure: this document was written by the agent that implemented zix, in the same
session. Every claim below is tied to a command that was actually run or a specific line of
code; anything not exercised end to end is labelled **not exercised**. Treat the strengths
section with the appropriate suspicion and the failure section as the load-bearing part.

## 0. Bottom line

- zix is a small, honest wrapper: it edits files, runs nix, verifies by evaluation, and
  rolls back. It does not build, deploy, or decide anything the repo's own checks do not
  already decide.
- Its pinning path is genuinely useful and safe (evaluation-verified, snapshot-backed).
- Its package-*updating* story is narrower than the name suggests: it moves **pins**. A
  package that lives in plain nixpkgs (like `herdr`) cannot be "updated to the latest" by
  zix today when nixpkgs itself is behind upstream (§5 is the worked case, with three
  independent verified reasons).
- zix's idea of "where a package is declared" does not cover the whole repo: it sees the
  curated `modules/*/packages.nix` lists and its own managed set, not the aspect files.
  `herdr` is declared in `modules/aspects/users/mei.nix` and zix reports it as undeclared.

## 1. What zix is

One Python 3 stdlib CLI (no third-party imports) over this dendritic configuration.
Repo-specific facts live in `zix.json`; zix code contains none of this repo's paths.

Four moving parts:

| Part | Job |
| ---- | --- |
| `zix.json` | the manifest: package targets, tool flake refs, switch commands, check suite, sandbox defaults, policy file |
| `zix/managed/` | `manifest.json` is canonical; `packages.nix` (the managed package list) and `pins.json` (attr → version) are generated from it |
| `tools/zix/` | `cli.py` + `zixlib/` (config, runner, backups, nixedit, managed, pins, tools, cmd_pkg, cmd_misc, cmd_sandbox, cmd_vm) + `tests/` |
| flake wiring | `modules/flake/apps.nix` (`mkZixApp`), `modules/flake/checks.nix` (the `zix` check), `modules/flake/dev-shells.nix` (a `zix()` shell function), `modules/shared/packages.nix` (imports the managed list), `lib/nixpkgs.nix` (pin overlay) |

Three kinds of declaration are managed:

1. the zix-managed set — installed on every host;
2. the curated lists `modules/*/packages.nix`, edited through `# BEGIN zix` / `# END zix`
   markers (whole-line matches only, so expressions and one-liners are never rewritten);
3. version pins — `zix/managed/pins.json`, applied by `inputs.multiverse.lib.pinOverlay` in
   `lib/nixpkgs.nix`, i.e. inside `mkPkgs`, which is why one pin reaches NixOS, nix-darwin and
   the standalone Home Manager despite `home-manager.useGlobalPkgs = true` (the overlay's own
   source comments call this out as the caller's job — the placement is deliberate).

The flake app wrapper bakes in the code only (`${self}/tools/zix/cli.py`); the repository is
discovered at runtime (`--repo`, `ZIX_REPO`, or walking up for the nearest `zix.json`). That
is what makes a store-copy invocation still edit the *working tree* rather than a read-only
store copy — necessary for a tool whose whole output is file edits.

## 2. Command surface

| Command | What it actually does | Verified how |
| ------- | --------------------- | ------------ |
| `doctor` | 10 probes: repo, managed files (parse + JSON), multiverse input presence, `nix`/`nix-instantiate` versions, git dirty count, container runtime + `/dev/fuse`, `/dev/kvm`, backups writability, tool count | ran it — all ok |
| `check [--full]` | runs `checks.quick` from `zix.json`; `--full` adds `nix flake check --all-systems --no-build` | ran both |
| `switch [HOST] [-- ARGS]` | argv prefix from `zix.json` + args, via the mutating runner | ran `switch -- --dry-run` |
| `update [-- ARGS]` | `nix run .#update -- ARGS`; the app supports `[flake-input...]`, `--flake-only`, `--local-only`, `--skip-flake`, `--skip-local`, `--package NAME` | usage text read; not exercised end to end |
| `follows check` | `nix-auto-follow -c`; exit 1 when the lock is not deduped | ran; found the deploy-rs/helium `flake-compat` duplicate |
| `follows fix` | `nix-auto-follow -i`, snapshotting `flake.lock`, rollback on failure | not exercised |
| `flakes list [--match S]` | `nix eval omniflake#lib.names` (+ substring filter, limit 40) | not exercised against the live index |
| `flakes run NAME [--pinned] [--attr A]` | `nix run omniflake#flakes.<name>.packages.<system>.default` (or `#pinned.<name>`) | not exercised |
| `pkg add NAME[@VER] [--target T] [--skip-check] [--no-verify]` | plain: append to a target; versioned: multiverse check → input ensure → declare → pin → evaluate `pkgs.<attr>.version` → rollback on mismatch | ran the full lifecycle (`hello@2.10` → 2.12.3) and the refusal path |
| `pkg rm NAME [--target T] [--all]` | removes declarations and the pin; refuses to guess when a name is declared in several targets | ran clean removal |
| `pkg unpin NAME` | drops the pin, returns the package to plain nixpkgs | by code inspection |
| `pkg list [--json]` | managed packages + pins (the only command that honours `--json`) | ran |
| `pkg where NAME` | locates declarations **in the tracked targets only** | ran — see §5 F2 |
| `pkg search QUERY` | `nix search` against the stable + unstable refs from `zix.json` | not exercised through zix; the repo's `search-pkgs` app (same `nix search`) was used during the herdr investigation |
| `pkg versions NAME` | `mvs query versions` passthrough — every version ever shipped | ran: `herdr · 9 versions · 2026-06-26 .. 2026-10-01` |
| `pkg update [NAME...] [--apply]` | reports how far **pins** are behind, `--apply` moves them (verifying each) | ran report mode; unpinned names are skipped |
| `input ls / add / remove` | edits `flake.nix` via `nixedit`, parse-validates, re-locks | `add` exercised during the first pin |
| `sandbox run/ls/exec/rm` | podman/docker run with the omnibin image, `--device /dev/fuse --cap-add SYS_ADMIN`, workspace + agent config mounts, `zix-` name prefix | `run` built defensively; lifecycle not exercised |
| `vm ...` | verbatim passthrough to rewindvm, with a `/dev/kvm` precheck | not exercised |
| `bin` / `wrap` / `grail` | passthroughs to omnibin / wrap-buddy / grail from the `tools` table | `wrap` warns when its argument is not a path (it patches in place) |
| global flags | `--repo`, `--dry-run`, `--json` (where supported), `--no-color`, `-q`, `--version` (0.1.0) | — |

Notes worth keeping in mind:

- **Global flags must precede the subcommand.** `zix pkg add herdr --dry-run` fails with
  `unrecognized arguments: --dry-run`; the working form is `zix --dry-run pkg add herdr`.
  The README says "all mutations support `--dry-run`" without the position caveat, and its
  own examples put flags after subcommands. This is finding F3.
- `switch` carries a dash-guard: `zix switch -- --dry-run` treats the dashed token as app
  arguments for the default host instead of a host name. `zix switch --dry-run` (no `--`)
  still dies in argparse.
- Command prefixes in `zix.json` end with `--` where they wrap `nix run`, so zix's arguments
  reach the app instead of nix. That is data, not code: a new switch must remember it.
- The update app has a per-package updater concept (`--package NAME`, for packages with
  `passthru.updateScript`, plus `linux-home-sources`). Nothing registers an upstream-flake
  updater, which is relevant to §5.

## 3. Safety model — and where it stops

What is actually enforced:

- every mutating operation snapshots its touched files into `zix/backups/` (kept, last 20)
  before writing; any failure (parse check, `nix flake lock`, pin verification) restores
  the snapshot and exits non-zero;
- text edits are validated with `nix-instantiate --parse` before anything else runs;
- pins are verified by evaluating `pkgs.<attr>.version` through the real policy file, not
  by trusting the write;
- idempotence is a rule: re-adding, re-removing, or re-pinning the same version is a no-op
  with an explanation;
- `--dry-run` prints diffs and skips state-changing commands (read-only probes still run).

Where it stops — each of these is a real gap, not a hypothetical:

1. **Plain adds are never existence-checked.** `pkg add NAME` (no `@version`) writes the
   name without evaluating it; a typo lands in the config and fails at build time. The
   README admits this; `doctor` does not compensate (it parse-checks the generated files,
   it does not evaluate the names).
2. **Verification can be skipped or inconclusive.** `--no-verify` exists, and when the
   verification eval "looks like a network problem" the pin is kept with a warning. So a
   pin can be recorded unverified — deliberately, but it means "verified" is not a
   guarantee in the column above.
3. **Rollback is per-invocation and scoped to the snapshot's file list.** Edits made
   outside that list between snapshot and failure are not restored.
4. **`pkg where` and `pkg rm` only see tracked targets.** Anything declared in an aspect
   file is invisible; see F2.
5. Backups are local and gitignored: they do not follow the repo to another machine.
6. Pins are global (all hosts, all systems) — the README lists this; the multiverse
   `pinOverlay` takes a flat `attr = version` map and derives the system from `final`, so
   there is no per-system dimension to set. Pinning a package that does not exist on
   aarch64-darwin has **not been exercised**.

## 4. How the fzakaria projects were integrated

Integration style, honestly: one of seven is deep (an input + an overlay + a verification
loop); six are argv passthroughs driven by one table in `zix.json`. The table is a real
design win — adding a tool is a data edit — but "integrated" for those six means "can be
invoked with the repo's context", not "understood by zix".

| Project | Depth | Mechanism |
| ------- | ----- | --------- |
| nixpkgs-multiverse | deep | `companion_inputs.multiverse`; `lib/nixpkgs.nix` applies `pinOverlay`; `pins.py` resolves with `mvs query versions --json`; every pin verified by evaluation |
| nix-auto-follow | shallow+ | `follows check` / `follows fix` (`-c` / `-i`), with a `flake.lock` snapshot and rollback |
| omnibin | medium | sandbox base image (`docker.io/fmzakari/omnibin:latest`, `/dev/fuse`, `SYS_ADMIN`) + `bin` passthrough; `doctor` reports `/dev/fuse` |
| rewindvm | shallow | `vm ...` passthrough; `/dev/kvm` precheck; x86_64-linux only, AMD needs `rewind pmu enable` per boot |
| omniflake | shallow | `flakes list` (`#lib.names`) and `flakes run` (`#flakes.<name>.packages.<system>.default`, `--pinned` for the author's pins) |
| grail | shallow | `grail ...` passthrough (version-range solver over the index) |
| wrap-buddy | shallow | `wrap ...` passthrough (Mic92's tool; the fzakaria post is the explainer) |

Deliberately **not** integrated, with reasons recorded in
`docs/research/fzakaria-tooling-review-2026-10-02.md`: trynix (browser-only), seenix
(visualisation), sqlelf/selfdb (SQL-over-ELF demos), guixpkgs (no fit), the
substituter-as-three-functions post, and the "AI slop" prose check.

Critical notes on the integrations themselves:

- **multiverse is the only one that constrains the config**, and it does so well: the
  overlay sits in `mkPkgs` where `useGlobalPkgs = true` cannot discard it, and the pin set
  is empty in steady state so the layer costs nothing. Its own limits are the interesting
  part: it can only serve versions that *shipped in nixpkgs*, its index has a snapshot
  horizon, and `minimize = true` means pins may be resolved through different revisions —
  correct, but it makes "which nixpkgs did my pin come from" a non-obvious question when
  debugging.
- **The six passthroughs all fetch floating refs.** `github:fzakaria/*` with no `rev`, and
  the sandbox image is a `:latest` tag; `SYS_ADMIN` plus `/dev/fuse` plus mounted agent
  credential directories (claude/opencode config) is a lot of trust for a convenience
  wrapper. The README says refs can be pinned in `zix.json`; the default is not pinned.
  This is finding F5.
- omnibin/rewindvm/wrap-buddy are all "when the NixOS hosts activate" tools in this repo's
  terms; on the CachyOS standalone host they are experiments, which is consistent with the
  review's trial rating.

## 5. Worked case: "update herdr to the latest version"

The request was a test of zix on a real package. `herdr` (the agent multiplexer,
https://herdr.dev) is declared as plain `pkgs.herdr` in `modules/aspects/users/mei.nix`.
Facts, all verified on 2026-10-02:

- the repo's nixpkgs pin (rev `4975466`, locked 2026-09-23) provides **herdr 0.9.1**;
- the multiverse index's newest herdr is **0.9.1** (9 versions since 2026-06-26; `0.9.1`
  marked `current`);
- today's nixpkgs **master tip** and **nixos-unstable tip** both still provide **0.9.1**;
- upstream's latest release is **v0.9.3** (2026-09-29);
- the nixpkgs bump is an **open, unmerged PR**: NixOS/nixpkgs#569162 `herdr: 0.9.1 -> 0.9.3`;
- upstream ships its own flake: `github:herdrdev/herdr/v0.9.3` exposes
  `packages.<system>.default`, `packages.<system>.herdr`, and `overlays.default`.

So there are three independent reasons zix cannot deliver 0.9.3 today:

1. `zix pkg add herdr@0.9.3` refuses by design — observed:
   `error: herdr@0.9.3 never shipped in nixpkgs; recent versions: ..., 0.9.0, 0.9.1`.
   The pin path can only serve versions that shipped.
2. `zix update -- nixpkgs` (selective bump) cannot help: the newest nixpkgs *tip* is 0.9.1.
   A bump would move a hundred packages to buy nothing here.
3. zix has no concept of a package whose origin is an upstream flake, so the one route that
   would work today — the upstream `v0.9.3` flake — is outside the tool's model. (The
   no-overlay policy removal makes the mechanism legal; nothing implements it.)

The shape of that gap is worth naming: zix models **nixpkgs history** (multiverse) but not
**upstream releases**. The repo has grown two adjacent mechanisms for the same family of
problems (`config/package-exceptions.json` pins for unfree packages, `scripts/check-unfree-pins.py`
for drift) and zix has neither an "outdated" view nor an upstream-origin path.

### Findings from the test

- **F1 — no path beyond nixpkgs.** As above. Impact: "update X to latest" works only while
  nixpkgs is current; for anything newer, the answer is "wait for nixpkgs" (fine when a PR
  is open, silent when nobody filed one). Suggest a third pin kind: `pkg add NAME@<flake-ref>`
  (or an `upstream` subcommand) that adds the input, consumes `inputs.<name>.overlays.default`
  when present, and verifies `<name> --version` rather than `pkgs.<attr>.version`. herdr is
  the natural first case: it is already checked in by `inputs.multiverse`-style machinery.
- **F2 — declaration coverage is narrower than the docs imply.** `zix pkg where herdr`
  printed `herdr is not declared anywhere zix tracks` while `modules/aspects/users/mei.nix:61`
  holds `pkgs.herdr`. Consequences: `pkg rm herdr` cannot remove that declaration, and
  `zix --dry-run pkg add herdr` *plans to add it* to the managed set (a duplicate). The
  README's "locate a declaration" over-promises; the tracked targets are package lists only.
  Suggest either an aspect-aware target kind (grep of `pkgs.<name>` across `modules/`) or an
  explicit "untracked" warning in `where`/`rm`.
- **F3 — global flags must precede the subcommand.** `zix pkg add herdr --dry-run` →
  `error: unrecognized arguments: --dry-run`. Suggest accepting `--dry-run` at the
  subparser level too (or normalising argv before parse) so the natural form works.
- **F4 — `pkg update NAME` for an unpinned package is a dead end.** Observed:
  `warning: herdr is not pinned; skipping` then `nothing changed; add --apply ...`. For a
  name whose nixpkgs version can be reported, the useful answer is "not pinned; nixpkgs
  has 0.9.1, multiverse's newest is 0.9.1, upstream is 0.9.3". Right now the user has to
  assemble that by hand (as this review did).
- **F5 — floating tool refs and a `:latest` sandbox image.** Convenience over provenance.
  Suggest an optional `rev`/digest field with a documented `latest` escape, and letting the
  sandbox image be pinned by digest.

## 6. Critical assessment

Strengths (with evidence):

- **Verification-first pinning.** A pin is not "done" until `pkgs.<attr>.version` evaluates
  to the requested version through the real policy. The development of this feature hit a
  Nix precedence bug in the verify expression and the rollback restored every touched file —
  the safety net has fired for real, not just in theory.
- **`--dry-run` reaches the file layer.** Diffs are printed by the same code path that
  writes them, so dry-run output cannot drift from behaviour.
- **Marker discipline respects the repo's own rules.** Whole-line token edits mean zix
  cannot rewrite an expression, a commented package, or a one-liner; the dendritic
  boundary tests are unaffected by design rather than by luck.
- **One headless companion input.** Six of seven external tools cost no closure. `doctor`
  shows "7 configured tools" and the pins path is the only one wired into evaluation.
- **The check-suite proxy is honest.** `zix check` runs exactly the repo's scripts; the
  flake's `zix` check runs the same `tests/zix.sh`, so CI and the CLI cannot disagree about
  what "passing" means.
- **Small surface.** ~2,000 lines of stdlib Python (~2,400 with its tests); no third-party
  imports; no daemon, no state outside the repo.

Weaknesses (ranked; evidence, impact, direction):

| # | Weakness | Evidence | Impact | Direction |
| - | -------- | -------- | ------ | --------- |
| 1 | Cannot express anything newer than nixpkgs (F1) | §5, three verified reasons | "Update to latest" silently stops at nixpkgs's edge | upstream pin kind (input + overlay + `--version` verify) |
| 2 | Declaration index misses aspect files (F2) | `pkg where herdr` vs `mei.nix:61` | `where` misleads; `rm` leaves declarations; `add` can duplicate | scan `modules/` for `pkgs.<name>`, or label untracked hits |
| 3 | Floating refs / `:latest` / SYS_ADMIN (F5) | `zix.json` `tools.*`, sandbox defaults | supply-chain trust unpinned by default | optional `rev`+digest fields; document the escape |
| 4 | Plain add unvalidated; doctor does not evaluate names | `_add_plain`; doctor's managed-files probe | typos reach the build; failures arrive late | evaluate existence in `add` (or a doctor probe) |
| 5 | Verification can be skipped or recorded unverified | `--no-verify`; network-warn path | "verified" is not always a guarantee | record `verified: true/false` per pin in `pins.json` |
| 6 | Pins are global; per-system behaviour unexercised | `pinOverlay` signature; `pins.json` shape | a linux-only pin could break the darwin host | document, or add a `systems` field |
| 7 | `--json` on one command only | `cmd_list`; others ignore it | scripting needs text scraping | honour `--json` broadly |
| 8 | Tests are stub-based; sandbox/vm/input paths untested | `tests/zix.sh` step 2 (unittest with stubs), step 3 (read-only smoke) | regressions in `cmd_misc`/`cmd_sandbox` are invisible in CI | opt-in network integration test; more fixtures |
| 9 | "Works for any repo" is unproven | single consumer repo; `system`, multiverse URL, agent mounts still partly hardcoded | the extension story is a promise, not a demonstration | second-repo smoke, or a schema doc + validation |
| 10 | Paper cuts | F3 (flag position), `switch --dry-run` needs `--`, `pkg update` name semantics | friction, not correctness | argv normalisation; friendlier hints |

Two framing notes, in fairness:

- zix is consciously **not** a build tool, a deploy tool, or an authority: it shells out to
  `nix`, `home-manager`, `nix-auto-follow`, `mvs`, and lets `nix flake check` remain the
  gate. That is the right shape for this repo, and the times it was slowest in development
  were exactly the times it tried to be clever about Nix semantics instead of delegating.
- The README's "Limits / roadmap" section already lists half of this table (global pins,
  unvalidated plain adds, network-dependent checks). The tool's self-documentation is more
  honest than its command names suggest; the gap that is *not* disclosed is F1/F2/F5.

## 7. Recommended next steps (ordered by value/effort)

1. **Upstream pin kind** (F1): `zix pkg add NAME@github:owner/repo/vX.Y.Z` — add the input,
   prefer `overlays.default`, fall back to `packages.<system>.default`, verify with
   `--version`. First case: herdr (v0.9.3) — and if the nixpkgs PR merges first, `pkg unpin`
   returns it to nixpkgs.
2. **Declaration discovery** (F2): make `where`/`rm` see aspect-file declarations, or print
   an explicit untracked-hit warning. Cheapest version: `grep -n "pkgs\.<name>\b"` over
   `modules/` as a fallback in `declared_where`.
3. **Outdated view** (F4): one command that answers "what of mine is behind, and behind
   what" — pins vs multiverse, plain declarations vs nixpkgs tip, URL-shaped ones vs
   upstream. Even a read-only report closes most of the surprise.
4. **Provenance defaults** (F5): allow `rev` in tool entries and digests in the sandbox
   image; keep `latest` but make it a deliberate choice.
5. **Verify honesty** (weakness 5): write `"verified": true` (or omit on skip) in
   `pins.json`, and let `pkg list` show it.
6. **JSON everywhere** (weakness 7) and the two paper cuts (F3): argv normalisation so
   `--dry-run` works in either position.
7. **Second-repo proof** (weakness 9): run zix against a throwaway config with a minimal
   `zix.json` and record what breaks — that is the only way "extensible" becomes true.

## Appendix A — verification log (2026-10-02)

- `nix flake check --all-systems --no-build` → exit 0, `checks.x86_64-linux.zix` present
  (39 attributes green, 0 red); before today's deploy-rs and unfree-pin fixes the same
  command failed on the darwin toplevel.
- `python3 tools/zix/cli.py doctor` → 10/10 ok (Determinate Nix 3.21.5, podman 5.8.7,
  `/dev/fuse` present, `/dev/kvm` rw, 7 configured tools).
- `zix pkg add hello@2.10` → `pkgs.hello.version == "2.10"` (plain nixpkgs: 2.12.3);
  `zix pkg update --apply` → 2.12.3; `zix pkg rm hello` → clean removal.
- `zix follows check` → one dedupe: deploy-rs and helium each carry their own `flake-compat`.
- `zix pkg versions herdr` → 9 versions, 0.7.0 (2026-06-26) .. 0.9.1 (current).
- `zix pkg where herdr` → "not declared anywhere zix tracks" (F2).
- `zix --dry-run pkg add herdr` → plans a managed-set add (F2, duplicate risk).
- `zix --dry-run pkg add herdr@0.9.3` → refusal listing recent versions (F1).
- `zix pkg update herdr` → "not pinned; skipping" (F4).
- `zix pkg add herdr --dry-run` → argparse error (F3).
- nixpkgs master/unstable tips + upstream release + PR #569162 checked via `nix eval` and
  the GitHub API, same day.

## Appendix B — inventory

| File | Lines |
| ---- | ----- |
| `tools/zix/cli.py` | 255 |
| `tools/zix/zixlib/cmd_pkg.py` | 413 |
| `tools/zix/zixlib/cmd_misc.py` | 349 |
| `tools/zix/zixlib/nixedit.py` | 174 |
| `tools/zix/zixlib/pins.py` | 154 |
| `tools/zix/zixlib/cmd_sandbox.py` | 139 |
| `tools/zix/zixlib/managed.py` | 123 |
| `tools/zix/zixlib/config.py` | 110 |
| `tools/zix/zixlib/util.py` | 101 |
| `tools/zix/zixlib/backups.py` | 81 |
| `tools/zix/zixlib/runner.py` | 57 |
| `tools/zix/zixlib/cmd_vm.py` | 33 |
| `tools/zix/zixlib/tools.py` | 30 |
| `tools/zix/tests/test_zix.py` | 385 (18 tests, offline stubs) |
| `tests/zix.sh` | 35 (unit run + read-only smoke) |
| `zix.json` | 122 |

Related documents: `tools/zix/README.md` (user manual), `docs/service-notes/zix.md`
(operations note), `docs/research/fzakaria-tooling-review-2026-10-02.md` (the tool survey
this integration rests on).


## Update (2026-10-07): F2 closed, runtime installs added, second repo proven

Follow-up session (the machine0 integration run); the same bias disclosure
applies - every claim below is tied to a command that was run.

- **`zix get NAME[@VERSION]`** - the runtime counterpart of `pkg add`. Verified
  end to end from an empty directory: `zix get hello@2.10 --profile P`
  installed GNU Hello 2.10 through
  `github:fzakaria/nixpkgs-multiverse#fast.versions.hello."2.10".out` (no
  nixpkgs evaluation), and the installed binary reported
  `hello (GNU Hello) 2.10`. Installs are idempotent; `--eval-road` forces the
  evaluating fallback when the index lacks the attr or version.
- **F2 fixed**: `declared_where` now scans `modules/**/*.nix` for
  `pkgs.<name>` and reports `aspect` hits; `pkg rm` warns and refuses to edit
  those; `pkg add herdr` no longer plans a duplicate managed-set entry (the
  §5 consequence). Covered by fixture tests.
- **Repo-less operation**: `get` runs without a zix.json; other commands fall
  back to a system manifest at `/etc/zix/zix.json` (`ZIX_SYSTEM_CONFIG`).
  New manifest keys: `runtime_only`, `default_target`, `no_pins`.
- **Second-repo proof (§7.7)**: /home/mei/machine0 ships `zix.json` (targets:
  image -> modules/packages.nix; default_target: image; no_pins: true;
  tools.multiverse), a vendored CLI, `pkgs/zix`, `m0coding.zix.enable`, and a
  runtime manifest; `nix flake check` and `nix build .#zix` are clean and the
  add/rm round trip against `modules/packages.nix` parses. Every multi-repo
  blocker the review predicted materialised exactly as listed; the fixes are
  the manifest keys above.
- **F1 (upstream pins) and F4 (outdated view) remain open** as recommended
  next steps. F5 (floating tool refs) unchanged. F3 (global flag position)
  unchanged.
- Tests: 18 -> 25 offline tests; `bash tests/zix.sh` PASS including the
  working-tree guard.
