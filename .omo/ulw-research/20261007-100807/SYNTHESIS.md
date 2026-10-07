# ULW-Research Synthesis: zix x machine0 x Railway lightweight agent images

Members + lanes: 17 (8 members, 9 lanes; provider 429 killed 7 members mid-flight and all 9
retrieval lanes after their reported facts) - Waves: 2 - Excursions: 3 - Sources: 20 ledger entries (~18 domains) - Verifications: 11 executed proofs - Debate rounds: 3
(1 full, 2 verdict-only) - Elapsed: see briefing.

## Executive summary

The user's three asks were delivered as working, verified artifacts: (1) the zix CLI now has a
runtime install path - `zix get NAME[@VERSION]` installs any nixpkgs version every published,
without evaluating nixpkgs, without a repository on disk, and it is integrated into machine0
both as the in-image runtime CLI and as repo tooling (`nix run .#zix -- pkg add`);
(2) a Railway-ready agent image project exists at /home/mei/railway-nix-agent - alpine + apk-nix
(44 MiB base vs the reference's 154 MiB nixos/nix base and 561 MiB published image), the agent on
loopback behind Caddy basic auth, `/healthz` open, built and validated locally end to end
(numbers in the Validation section); (3) omo-native packaging moved from `omo-ai@beta 5.0.0-0.beta.82`
to the stable `omo-ai@5.1.22`, independently hash-verified, built, and run (`omo 5.1.22`,
engine senpi 2026.10.10-5).

The load-bearing mechanism behind all three is nixpkgs-multiverse's store-path index: every nixpkgs
version that Hydra ever built maps to the store path its build produced, so "get any package, any
version, whenever" becomes a cache fetch (6.8 s cold / 0.8 s warm in a stock container, ~325 MB peak
RAM in our image) instead of a nixpkgs evaluation (16-20 s, 784 MB peak measured; the reason the
reference template must declare a 1 GB plan floor). The critical review's F2 gap (declaration
coverage) is fixed; F1 (upstream pins) and F4 (outdated view) remain the recorded next steps.

## Findings by theme

### 1. Any package, any version, fast - and its real limits
- `zix get NAME[@VERSION]` resolves `github:fzakaria/nixpkgs-multiverse#fast.latest.<attr>.out`
  (or `#fast.versions.<attr>."<ver>".out`) and installs it with `nix profile`; verified from an
  empty directory: `zix get hello@2.10` -> `hello (GNU Hello) 2.10` [claim C1, C7].
- The claim "skips evaluation entirely" (review) is imprecise: the fast road evaluates 3 flake
  files and parses ~25 MB of JSON (cpuTime 0.76 s vs 5.37 s), fetches zero nixpkgs. "Substituted
  straight from cache.nixos.org" is true. Index cost: 20.6 MB per system [C1, debate round 1].
- Coverage limits are real: unfree/broken attrs and versions newer than the index pin (data-20261006)
  fail closed -> `get` falls back to the evaluating road and says so. Pre-2016 builds may substitute
  but crash on modern locale data (hello 2.7); `LC_ALL=C` fixes that class. "Any version" is not the
  same as "any version runs everywhere" [A3].
- omnibin (51,662 executables) cannot run on Railway: it needs /dev/fuse + SYS_ADMIN and Railway
  service containers are non-privileged. Same for zix's own `sandbox`/`vm` paths (also needs /dev/kvm) -
  the template states the supported command set [C5].

### 2. machine0 integration (the zix CLI in the image and in the repo)
- Runtime: the image ships `zix` (vendored CLI, `m0coding.zix.enable`, default on), a read-only
  system manifest at `/etc/zix/zix.json`, `~/.nix-profile/bin` on the nix user's PATH, and a MOTD
  that teaches the two commands. Runtime installs land in the invoking user's profile and survive
  the session; after a redeploy the profile manifest survives on the volume but the store path does
  not - re-running `get` repairs it in seconds (same caveat the reference documents for /nix).
- Repo tooling: `zix.json` (target `image` -> `modules/packages.nix`, `default_target: image`,
  `no_pins: true`, tools.multiverse, checks quick), `nix run .#zix -- pkg add NAME`, and
  `nix build .#zix`. The add/rm round trip parses; `doctor` is all-green [C7].
- The review's predicted blockers (managed-files probe, missing policy file, absent targets) all
  materialised exactly as listed; they are closed by the new manifest keys (`runtime_only`,
  `default_target`, `no_pins`) and the repo-optional command set [A5, review update].
- Second-repo proof (review section 7.7) is done: nix flake check clean, `nix build .#zix` built,
  `zix get hello@2.10` ran inside the repo-less path, 25 offline tests green [O8, O9].
- Slimming (the "lightweight images" half of the machine0 ask): the 38.39 GB image version is a
  snapshot, not the closure (~12.6 GiB). Measured levers: dsh -4.18 GiB, Playwright -2.14,
  rust -1.58, docker -0.90, devenv -0.86, omo -0.72, opencode -0.50 GiB; VM store garbage before a
  snapshot up to ~20 GB (assumed); a medium builder lowers Min. Disk from 80 to 60 GB. The image
  keeps the agents that cannot be substituted (dsh, claude-code: 373 derivations cold) and gets
  everything else on demand [C6, machine0 README section].

### 3. The Railway template (better where it counts)
- Shape: image-source template, one service, volume at /home/agent, generated `AGENT_PASSWORD`,
  `/healthz` open, everything else behind Caddy basic auth; agent on 127.0.0.1 via ttyd+tmux
  (omo flavor) or its own web server (dsh flavor). This mirrors the reference's proven security
  pattern (loopback + proxy, upstream refusals honoured) [C4].
- Lighter: base 44 MiB (alpine+apk-nix) vs 154 MiB (nixos/nix); our built image and measured
  numbers are in the Validation section. Faster: the fast install path removes the eval spike that
  forces the reference's 1 GB floor [C2, C8].
- Publish path is scripted (scripts/publish-template.sh): `railway init/add --image/volume add/
  templates create/templates publish`, with the dashboard-only steps called out (generated-input
  password, healthcheck) [A1].
- Not built here, honestly: the dsh flavor compiles at install (node-pty) and pulls a 4.18 GiB
  closure; the Dockerfile supports `--build-arg AGENT=dsh` but this run validated only omo and
  the AGENT=none flavor.

### 4. omo packaging
- 5.1.22 is the stable channel now (dist-tag latest; beta parked at 5.1.0). npm tree 12.7 MB
  unpacked / 620 files; engines node>=24; senpi engine 2026.10.10-5. buildNpmPackage recipe holds:
  new `npmDepsHash` computed and independently re-derived; built closure 776.2 MiB / 38 paths;
  `omo --version` -> 5.1.22 [C3].
- Surface: no serve/web/tui/server command in 5.1.22; the exposable headless surfaces are
  `omo app-server --listen ws://...` (Codex app-server protocol) and `omo host` (RPC daemon).
  The Railway flavor therefore serves a PTY (ttyd + tmux keeps the session alive across
  reconnects) rather than a built-in web UI [A6].
- A bun-compiled single binary builds (81.5 MB) but needs the on-disk engine tree at runtime, so
  the npm tree stays the shipped form - recorded as a dead end, not a packaging win [X2].

## Codebase findings (absolute paths)
- /home/mei/nixos/tools/zix/zixlib/cmd_get.py - new runtime install command (fast/eval roads,
  profile idempotence, PATH reporting, plain-list fallback for old nix).
- /home/mei/nixos/tools/zix/cli.py:19 (REPO_OPTIONAL), :84-97 (get subparser), main() fallback;
  zixlib/config.py runtime_only/default_target/no_pins + /etc/zix system manifest;
  zixlib/cmd_pkg.py declared_where aspect scan + rm guard + no_pins guard;
  zixlib/cmd_misc.py doctor runtime_only probes; tests 25 green.
- /home/mei/machine0: zix.json, modules/packages.nix, pkgs/zix/default.nix, tools/zix (mirror),
  modules/coding.nix (option, package, /etc/zix manifest, sessionPath, MOTD), flake.nix
  (packages.zix, apps.zix), README/CLAUDE.md updates.
- /home/mei/railway-nix-agent: Dockerfile, railway-entrypoint.sh, railway.json,
  scripts/validate.sh, scripts/publish-template.sh, vendor/zix, template/manifest.example.json.

## Sources (ranked; full ledger in sources-ledger.md)
1. nixpkgs-multiverse source + docs (github.com/fzakaria/nixpkgs-multiverse) - primary mechanism.
2. Railway primary docs (docs.railway.com plans/volumes/healthchecks/templates) + generated
   deploy manifest for the reference template - platform facts.
3. bon5co/deepseek-harness-railway repository (Dockerfiles, entrypoint, verify script) - the
   design being improved on.
4. /home/mei/nixos/docs/research/zix-cli-critical-review-2026-10-02.md + zix source - design input.
5. docs.machine0.io (cached + skill) and the machine0 repo/upstream clone - image lifecycle.
6. npm registry metadata + the omo-ai 5.1.22 tarball - packaging facts.

## Verified claims
| claim | verdict | evidence |
| --- | --- | --- |
| fast path: no nixpkgs eval, seconds-scale, few-hundred-MB | CONFIRMED (wording corrected) | A3 runs + lead runs; verify in wave-1-returns.md |
| alpine+apk-nix is viable and light (44.2 MiB) | CONFIRMED | A2 + lead container runs |
| omo-ai 5.1.22 packages and runs | CONFIRMED | build + --version; independent hash check |
| zix get repo-less runtime install | CONFIRMED | /tmp runs + 25 tests + rail image validation |
| Railway non-privileged: no FUSE/caps -> no omnibin/sandbox | CONFIRMED (docs + run) | C5 |
| reference image 561 MiB / ready 101 s / 0 s build | CONFIRMED (size measured; timing = platform manifest) | C8 |
| machine0 38.39 GB = snapshot payload; levers above | PARTIAL (levers measured; snapshot semantics documented, live CLI unavailable) | C6 |

## Epistemic instrumentation (see files)
- intent-diff.md: T1-T8 closed or explicitly partial; no silent diffs.
- claim-graph.md: C1-C9 with status, independence and counter-search recorded; C4 carries a
  documented single-group exception (platform docs primary).
- observation-manifest.md: O1-O9 across independent observer groups (member vs lead).
- verification-economics.md: every proof decision with cost and residual risk.
- cause-disappearance.md: CD1-CD5 (each closed with the observation that the violation vanished).
- excursion-log.md: X1-X3 with EXIT rules and what each changed.
- debate-log.md: round 1 full (C1 wording), round 2 partial (alpine).
- expansion-log.md: wave 1 (17 workers), wave 2 (lead-executed), convergence reason.

## Debate record
- Round 1: "skips evaluation entirely" attacked by A3's control measurement and lead execution;
  verdict: wording broken, substance holds; review updated.
- Round 2 (partial): alpine/musl attacked (no upstream musl release); verdict: holds with the
  caveat that musl nix is distro-versioned (2.23.3) and zix compensates (add->install probe).

## Contradictions
- Review says "fast path skips evaluation entirely" vs measurement (6-7 files / 25 MB JSON):
  resolved by the wording correction; both sources agree on the substance.
- Reference README claims a prebuilt dsh closure; A4 found the cache does not hold it today
  (373 derivations on a cold substitution) - recorded as a flag against the reference's claim
  (not re-verified by building).

## Gaps
- machine0 live image metadata (38.39 GB semantics) needs the machine0 CLI logged in.
- The dsh Railway flavor was not built or run here; its Dockerfile path is written but unverified.
- Railway's user-namespace availability inside service containers remains undocumented; our
  image does not need it (fast path works without), so the risk stays theoretical.
- F1 (upstream pins) and F4 (outdated view) remain open by design (scope).
- The publish flow itself (railway templates create/publish) was read from CLI help and docs,
  not executed (the user chose local-only validation).

## Expansion trace
- Wave 1: 17 workers -> ~40 leads, 1 debate; provider 429 killed the retrie                     eval lanes.
- Wave 2 (lead): reference teardown, compile probe, alpine measurements, implementation proofs;
  6 leads closed, none changed the top-level answer after X1-X3.
- Convergence: no unchecked lead remains actionable; residual unknowns above are recorded as gaps.

## Validation log (railway-nix-agent, final image v6, 2026-10-07)

`bash scripts/validate.sh railway-nix-agent:omo` - 15 pass / 0 fail:

| metric | value |
| --- | --- |
| auth | 401 on / , /token, wrong password, empty password, forged loopback Host; 200 with credentials |
| healthcheck | /healthz 200 unauthenticated (proxied through to the agent port) |
| binding | public port listening; agent bound on 127.0.0.1 only (checked via /proc/net/tcp{,6}) |
| zix get ripgrep (latest, cold) | 5 s |
| zix get hello@2.10 (pinned) | 1 s |
| zix get jq (warm) | 2 s |
| exact version runs | hello (GNU Hello) 2.10 |
| idempotence + zix get --list | pass |
| container memory.peak (boot + 3 installs) | 317,771,776 B = 303 MiB |
| idle RSS | 37.5 MB |
| image | 1.04 GB on disk; 413,365,638 B = 394 MiB gzip proxy for pull weight |
| reference comparison | 588.7 MB compressed / 76 layers; base 154 MB vs our 44.2 MiB |

Machine0 side (same day): nix flake check clean; nix build .#zix -> zix 0.2.0; tools/zix staged
mirror; 26 offline tests + tests/zix.sh PASS; zix get hello@2.10 from an empty directory installed
GNU Hello 2.10; omo build -> omo 5.1.22 (engine senpi 2026.10.10-5).
