# Claim Graph (updated 2026-10-07; wave-1)

| claim_id | statement | type | risk | scope | supporting observations | contradicting | independent groups | counter-search | primary source | status | location |
|---|---|---|---|---|---|---|---|---|---|---|---|
| C1 | multiverse fast path installs any indexed nixpkgs version with zero nixpkgs eval; 6.77 s cold / 0.79 s warm in a stock container; index cost 20.6 MB/system | code/perf | high | image design | A3 runs; lead runs (hello 2.10, ripgrep 15.2.0); zix-extensions run | review's "skips evaluation entirely" wording (corrected: evaluates 3 flake files) | 3 (A3, A5, lead) | adversarial: unindexed versions fail closed -> eval-road fallback (implemented) | multiverse source multiverse.nix:741-960 + own execution | supported | SYNTHESIS, README |
| C2 | alpine + apk-nix is a working, lighter base: 44.2 MiB image; glibc store paths substitute and run on musl | code/perf | high | railway image | A2 measurements; lead runs (ripgrep, hello) | none found | 2 | A8 attacked musl theory: official nix has no musl release, but apk ships musl nix and glibc closures are self-contained (executed) | own execution + apk package | supported | SYNTHESIS, Dockerfile |
| C3 | omo-ai@5.1.22 is npm latest, packages by buildNpmPackage under node>=24; built binary reports 5.1.22 | code | high | machine0 + railway | lead build + omo --version; A6 independent hash verification | none | 2 | A6 verified lockfile hash independently | npm registry + own execution | supported | machine0 repo, SYNTHESIS |
| C4 | A Railway image-source template with a generated password, /healthz, loopback-only agent and 1 GB floor is the publishable shape; Free/Trial cap images at 4 GB | platform | normal | railway template | A1 docs sweep + manifests | none found | 1 (railway-platform) + lead read of reference README | A1 searched for image-cap changes: none | docs.railway.com | supported (single-group exception recorded) | template/ |
| C5 | Railway containers are non-privileged: /dev/fuse, --cap-add and DinD unavailable; zix sandbox/vm cannot run there; omnibin cannot run there | platform | normal | template scope | A1 addendum; A3 omnibin run; A8 station answers | none | 3 | A3 tested FUSE requirement locally | docs.railway.com + execution | supported | README, SYNTHESIS |
| C6 | m0-coding image v3 (38.39 GB snapshot / Min. Disk 80 GB) is dominated by machine state + big closures; disabling dsh (-4.18 GiB), playwright (-2.14 GiB), trimming rust/docker/devenv are the top levers | code/perf | normal | machine0 | A4 narinfo sums + upstream source | 38.39 GB semantics is ASSUMED (no CLI login) | 1 + lead reads of upstream | A4 flagged the assumption explicitly | upstream + cache narinfo | partial (levers measured; snapshot semantics assumed) | SYNTHESIS |
| C7 | zix required a repo (zix.json) for every real subcommand; now `get` runs repo-less and falls back to a system manifest at /etc/zix | code | high | both repos | A5 source read; lead implementation + tests (25) + real runs | none | 2 | tests/zix.sh PASS incl. repo-less dry-run | source + execution | supported | zix README, service note |
| C8 | The reference image is ~561 MiB compressed and typical_ready_seconds=101 (build 0 s, start 22 s) | perf | normal | comparison | A1 measured the GHCR manifest + docs phases | none | 1 + lead manifest fetch | none needed | railway manifest.json | supported | SYNTHESIS |
| C9 | Alpine's nix 2.23.3 lacks `nix profile add`; zix probes add->install; plain-text `profile list` fallback added for old nix | code | normal | railway image | lead alpine runs | none | 1 + member hint | executed on alpine (add failed, install worked) | execution | supported | zix source |


## Corrections (wave 2)
- C1 note: the "unfree throws" limit A3 recorded was REFUTED by A8 (vscode fast path substituted,
  exit 0). Fast-path limits are narrower than first recorded: absent-from-index attrs and
  post-pin releases fall back; unfree is not categorically excluded where the index matched a
  Hydra build.
- C2 note: alpine:latest carries nix 2.31.5 (3.21 carries 2.23.3); our image pins 3.21 and
  compensates via zix's add->install probe; switching base is a recorded follow-up.
- New: C10 - npm 11.19 CLI blocks dependency install scripts by default; the nix build path for
  machine0's omo is NOT affected (engine stamp present, esbuild 0.28.2) - evidence captured.
