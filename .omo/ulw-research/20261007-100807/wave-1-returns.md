# Wave 1 returns (condensed, orchestrator-recorded 2026-10-07)

Team: ulw-research-m0-railway (a35b1eb9-c26c-4590-a4d8-ba1e6fb21e48), 8 members + 9 lanes.
Provider note: at ~19 min an account-wide opencode-go 429 ("Go usage limit exceeded",
retry-after ~17 days) killed every still-running member and lane. Members A1/A3/A5/A4 had
delivered full reports; A6 delivered a rich interim; A8 delivered recon findings 1-4 before
death. Laned retrieval (E1,E2,L1-L4,B1,B2,R1) died before delivering - the lead covered their
territory directly (see below). No lane result is treated as evidence; nothing was approved
that did not deliver.

## A1 railway-platform (COMPLETE)
- Template = PROJECT SNAPSHOT, not a repo format. Dashboard: workspace/templates -> New Template;
  CLI: `railway templates create -p <project> -e <env> --json` -> `railway templates publish <id>
  --category <CAT> --description ... --readme-file README.md --image <card> --json`. First publish
  requires a readme.
- An IMAGE-source template requires NO repo files; config lives in the template (serializedConfig).
  Repo-source templates auto-detect Dockerfile (capital D) + railway.json.
- Marketplace artifacts: /deploy/<slug>.md + /deploy/<slug>/manifest.json ("TemplateCI"-validated).
  Third-party validator: github.com/railwayapp/template-best-practices (public app).
- Plans: Free .5GB/1vCPU; Trial 1GB/2vCPU; Hobby 48GB/48vCPU (per-replica cap 8GB); Pro 1TB.
  IMAGE SIZE CAP: Free/Trial 4 GB, Hobby 100 GB. Volumes: Hobby 5 GB default.
- Deploy speed: image source SKIPS build; typical_ready_seconds=101 = initialize+pull/extract+
  create/start(22s)+healthcheck settle. Reference image measured 588,718,575 B (561 MiB)/76 layers.
- Runtime: containers NON-PRIVILEGED (no DinD, no FUSE/--cap-add); RAILWAY_RUN_UID=0 for root;
  RAM is a hard cap -> exit 137 OOM.
- Config-as-code (railway.json/toml) DEPRECATED, legacy until 2026-12-01; .railway/railway.ts is
  the forward path. Healthcheck: any 2xx, default 300s timeout. restartPolicy default ON_FAILURE.
- Recommendation (adopted): image source pinned by digest; healthcheckPath /healthz with
  healthcheckTimeout 60; sleepApplication false; limitOverride memoryBytes; generated strong
  password input; 1 GB floor honest while eval-heavy paths exist.
- Addendum (cross-axis): zix sandbox/vm need /dev/fuse+SYS_ADMIN+/dev/kvm -> cannot run on Railway.
  Template must state the supported command set; Railway Sandboxes (VM primitive) is the escape hatch.

## A2 nix-container-lab (partial, then 429)
- Bases measured (podman, on-disk): alpine:3.21 7.7 MiB; debian:stable-slim 77.5 MiB;
  ghcr.io/nixos/nix:latest 561.6 MiB (69 layers).
- Final image deltas: alpine+apk-nix 44.2 MiB total; debian+official-installer 235.4 MiB;
  apk nix = 35 MiB of packages, nix 2.23.3, store empty until init, nix-command DISABLED by default.
- Official installer in a container: root+--no-daemon fails; needs pre-created /nix AND
  /etc/nix/nix.conf with `build-users-group =` (empty) — proven rc=0 (debian: 121 MB /nix, nix 2.35.2);
  alpine additionally needs coreutils for `cp --preserve=ownership,timestamps`.
- sandbox=true proven working under rootless userns; nix-daemon idle ~39 MB RSS (single-user has none).
- Cold install (eval road) 16-20 s at 784 MB peak RSS; warm <=1.2 s. (Their earlier 10232 kB sampler was
  a bug they caught and fixed with podman top ... hpid; only corrected numbers are used here.)

## A3 multiverse-runtime (COMPLETE)
- Fast path: zero nixpkgs fetch + zero nixpkgs evaluation (6-7 evaluated files, all multiverse's own).
  WARM 1.11 s / peak RSS 158 MB; STOCK container (nixos/nix, nix 2.35.2): 6.77 s COLD / 0.79 s warm.
  Control via eval path: 233 evaluating-file lines, 226 from nixpkgs; cold 2022 revision 10.92 s + a
  99.2 MB nixpkgs -source tree.
- Index cost 20.6 MB per system (flake 4.16 MB + outpaths 13.53 MB + tip-outpaths 1.49 MB + outs 5.54 MB).
- Old versions substitute (hello 2.10 ran; hello 2.7 substitutes but crashes on host locale -> LC_ALL=C;
  boundary ~2016). Unfree/broken releases refuse; no `nix run` on a fake (use profile install / nix shell).
- Requires nix-command+flakes; no --impure, no fetch-tree, no FUSE.
- Review wording corrected: "skips evaluation entirely" is FALSE as written (it evaluates 3 flake files +
  parses ~25 MB JSON); "substituted straight from cache.nixos.org" is TRUE.
- omnibin: 399 MiB, needs /dev/fuse + SYS_ADMIN -> CANNOT run on Railway. mvs first run: 264 s build +
  0.59 GB closure; warm queries 1.8-2.9 s.
- NixOS VM wiring: runtime on-demand (flake input + nix in image) is the cheap shape; build-time pins use
  the EVAL path (99-189 MB nixpkgs tree per revision) - right for policy, wrong for on-demand.

## A4 machine0-platform (COMPLETE report, then 429)
- Lifecycle: images are SERVER-SIDE snapshots (no upload path); builder disk = Min. Disk
  (ext4 growPartition/autoResize); m0-coding v3 snapshotted from a large VM -> Min. Disk 80 GB.
  38.39 GB = snapshot payload (image-layer /nix incl. build leftovers + docker + journal), NOT the
  declarative closure (local build 3.81 GiB qcow2.gz from a 17.52 GiB disk).
- Sizes/pricing: small 25GB $0.013/h; medium 60GB $0.034/h; large 80GB $0.052/h; xl 160GB $0.104/h;
  images $0.078/GB-month; suspend = snapshot + delete.
- Closure (narinfo-summed): system runtime 822 paths / 7.70 GiB; dsh +4.18 GiB; omo +0.72 GiB;
  ~12.6 GiB total consistent with README's 11 GiB.
- Lever table (MEASURED unless noted): dsh off 4.18 GiB; playwright off 2.14 GiB; rust 1.58 GiB;
  docker 0.90; devenv 0.86; omo 0.72; opencode 0.50; gcc-wrapper 0.34; git 0.33; go 0.22; python3 0.17;
  bun 0.13; cmake 0.13; docker-compose 0.10; VM-store garbage before snapshot up to ~20 GB (ASSUMED);
  smaller builder 80->60 GB; seed-store = time not GB.
- Speed: provision = sync + nixos-rebuild on the VM (~10 min budget); first provision substitutes/builds
  the full closure; max-jobs=1/cores=1; dsh substituter only live after the switch (m0-dev patches
  /etc/nix/nix.conf first). dsh+claude-code NOT substitutable today -> 373 derivations to build on a
  cold cache (flag: the README's prebuilt-closure claim is contradicted for dsh).
- Runtime on the VM: `nix profile add nixpkgs#X` via the daemon; profile gc-rooted; allowUnfree=true;
  live substituters incl. devenv + deepseek; optimise.automatic daily; gc weekly 14d.
- Assumptions flagged: 38.39 GB semantics (CLI not logged in); hermes closure; dsh cache state.

## A5 zix-extensions (COMPLETE, plan)
- Verified end to end first: `nix build --no-link --print-out-paths
  'github:fzakaria/nixpkgs-multiverse#fast.latest.hello.out'` -> store path; `nix profile install
  --profile <tmp> <ref>` -> working hello. Negative: `fast.latest.hello.out.outPath` does NOT exist.
- Seams for `zix get`: cli.py:80/113/188/233 dispatch; runner.py:37-41 mutating/dry-run; backups.py:34
  snapshot is the only mkdir (runtime get is safe read-only). Every real subcommand needs a zix.json
  (cli.py:240-245, config.py:94-96) -> either a baked manifest + ZIX_REPO or repo-optional get.
- F1 upstream pin kind design (input + overlay + verify via verify_pin); F2 one-function change
  (declared_where) + rm guard; F4 `pkg outdated` sketch; 12 multi-repo blockers enumerated.
- Recommendation adopted: implement `get` + machine0 vendored CLI + baked manifest.

## A6 agent-packaging (interim, then 429)
- Bump INDEPENDENTLY verified: prefetch-npm-deps on the working-tree lockfile (sha256 c7e07e10...)
  prints sha256-8XPFa9iW+F5gvpDiJ70hAFVsv/Zaf6ngDKwvqQ8IIeI= = the declared npmDepsHash; nix build .#omo
  exit 0 -> /nix/store/x7sb...-omo-5.1.22 (528M, 27927 files, closure 776.2 MiB/38 paths).
- Runtime: launcher re-execs under bun when bun >= 1.4 present; BUN_MIN_VERSION=1.4.0; node 24 works;
  image (bun 1.3.3) stays node deterministically.
- Sizes: npm ci tree 517M/27923 files (260 pkgs, 10 s); bun install 745M (adds linux-x64-musl dup
  ~229M); bun compile exit 0 (lead measured: single binary 81.5 MB, but it needs the on-disk engine
  tree at runtime -> npm tree stays the shipped form).
- omo CLI surface: NO serve/web/tui command; `omo app-server --listen ws://127.0.0.1:18991`
  (Codex app-server protocol), `omo host ...` RPC daemon, `omo auth print-*`, `omo schedule`;
  gateway requires a separate package. -> The Railway surface for omo is a PTY (ttyd) or app-server,
  not a built-in web UI; dsh keeps its web UI.
- dsh: source HEAD c19a93e; presets.tui built from pkgs/presets + pkgs/bundles/tui; RAM evidence =
  machine0 README + flake comment (node/esbuild kernel bundle OOM on 2vCPU/4GB).

## A8 skeptic (recon 1-4, then 429)
- Reference repo is bon5co/deepseek-harness-railway (the -nixos-railway image slug 404s);
  dsh upstream ships NO auth and REFUSES non-loopback binds; wrapper = Caddy basic-auth on $PORT ->
  dsh web 127.0.0.1:3080 with Host/Origin rewrite; password persisted on the volume; unauthenticated
  /healthz. Node-pty compiles at install (toolchain required).
- Official nix Linux artifacts are glibc-only (nix-*-musl.tar.xz -> 404); Alpine edge has nix 2.31.5-r3.
- Claims to keep: dsh bind refusal is upstream-enforced; omnibin/Railway impossibility.

## Lead-covered territory (lanes died)
- Reference Dockerfile/entrypoint/verify suite fetched from GitHub (raw): exact Caddy auth pattern,
  password precedence, loopback rewrite rationale, 561 MiB image, PATH notes, volume caveat for /nix.
- Alpine experiments rerun by the lead: nix 2.23.3 needs `nix profile install` (no `add`); fast-path
  install of ripgrep 15.2.0 works; peak memory.peak fast ~325 MB vs eval road ~1.35 GB (same container);
  hello 2.12.3 substituted and ran on musl.
