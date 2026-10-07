# ULW-Research Brief - zix x machine0 x Railway light agent images

Started: 2026-10-07T14:13:58.794Z | Session dir: /home/mei/nixos/.omo/ulw-research/20261007-100807
Orchestrator: omo (nixos-ac259190). This directory is the run's durable state; journal in real time.

## Core question (fixed goal; excursions must fold back to it)
1) Integrate the zix CLI into the machine0 project (/home/mei/machine0 = m0-coding, a private consumer flake of github:fdmtl/machine0-nixos) so coding agents ON machine0 images can obtain any package they want, any version, whenever they want - with images as lightweight as possible and new-image setup fast. Design input: /home/mei/nixos/docs/research/zix-cli-critical-review-2026-10-02.md (F1 no path beyond nixpkgs; F2 declaration coverage; F3 flag position; F4 update dead end; F5 floating refs).
2) Make a Railway deploy template in the same idea-space as https://railway.com/deploy/deepseek-harness-on-nixos-or-just-update (agent + nix for on-demand packages, password-gated, persistent volume) but lighter/faster/better; proof = local build + measured size/idle-RAM/install latency + a validated template manifest.
3) Bump omo-native packaging in /home/mei/machine0 from omo-ai@beta 5.0.0-0.beta.82 to omo-ai@5.1.22 (npm latest; dist-tag beta is 5.1.0). engines.node >=24; depends on @code-yeongyu/senpi 2026.10.10-5.

## Verified facts so far (this session; add as they land)
- /home/mei/machine0: m0-coding image v3 = 38.39 GB, min disk 80 GB (large); 189 packages; omo 5.0.0-0.beta.82 baked from pkgs/omo buildNpmPackage; dsh from github:moraxyc/deepseek-harness.nix presets.tui; autoUpgrade mkForce-disabled; bin/m0-{build,dev,snap,new}. git main @c96aacb, clean.
- omo bump recipe (pkgs/omo/default.nix header): npm view omo-ai@beta version -> set version in default.nix + package.json -> npm install --package-lock-only -> prefetch-npm-deps -> npmDepsHash.
- zix: tools/zix Python stdlib CLI over zix.json; commands pkg/input/sandbox/vm/follows/flakes/switch/check/doctor; snapshot+verify+rollback safety; flake app nix run .#zix; multi-repo via --repo/ZIX_REPO (unproven). Review: ~2000 LOC, 18 offline tests.
- Railway: CLI v5.30.4 authenticated as Nathan (nathanagbomed@proton.me). Reference template manifest format captured (manifest_version 1.0.0, template.upstream.image, services[].source.image, required_inputs generate strong_password, deploy.api, post_deploy.healthcheck, resources). Reference image ghcr.io/bon5co/deepseek-harness-nixos-railway:0.1.0-rc.6, idle 135 MiB, plan floor 1 GB, typical_ready_seconds 101.
- machine0 CLI 1.0.164 installed but NOT logged in (no live VM/image ops without user action).
- Local tooling: nix (Determinate 3.x), podman 5.8.7, docker, gh, bun 1.4.2, node; disk 274G free; no railway 'use-railway' skill installed (railway setup agent offered).

## Analysis
Core question: the lightest, fastest path for an agent (on machine0 images and on Railway) to acquire arbitrary packages/versions at runtime, and how zix becomes the CLI for that path.
Axes: A1 Railway platform + template format; A2 nix-in-minimal-container engineering; A3 multiverse fast-path installs; A4 machine0 platform + image slimming; A5 zix extension seams; A6 agent packaging (omo 5.1.22, dsh); A7 Dockerfile/assembly design; A8 adversarial attack (skeptic).
Codebase relevant: yes (nixos/tools/zix, machine0 repo, upstream machine0-nixos) | External: yes | Browsing: yes | Verification: yes (local container builds + measurements) | X/social: no.
Scale: 8 axes, 6+ source territories -> lifecycle: ONE research team + lanes; then implementation + verification by execution; refinement debate inside the same team (ulw-research default).
Debate needs: light-path vs nix-eval RAM; alpine/musl vs debian/glibc for nix; single-user vs daemon store; what zix needs to become a runtime installer; whether the m0 image can shrink; omo serving surface on Railway.

## Team roster (members; one axis each; mixed tiers)
| member | category | axis |
| railway-platform | deep-low | A1 Railway mechanics, template format, limits, deploy-speed determinants, publish path |
| nix-container-lab | deep-low | A2 run nix in a tiny container: base choice, static/musl, single-user store, sandbox flags, caches; local podman experiments |
| multiverse-runtime | deep-low | A3 multiverse/mvs fast path + omnibin: any version, no big eval, cache behavior, RAM/time numbers |
| machine0-platform | deep-low | A4 machine0 image lifecycle + how to slim 38.39 GB and speed new-image setup; docs.machine0.io + upstream repo |
| zix-extensions | deep-low | A5 zix seams: runtime install surface + F1/F2/F4 fixes; change plan with file:line |
| agent-packaging | unspecified-high | A6 omo-ai 5.1.22 packaging delta + lightest agent install (omo/dsh) on both surfaces |
| dockerfile-design | deep-low | A7 assemble the Railway Dockerfile design: multi-stage, base, compression, healthcheck, entrypoint, volume, auth proxy |
| skeptic | ultrabrain | A8 attack: claims, evidence independence, design weaknesses, 'better' claims |

## Lanes (curated, read-only; 9)
E1 explore: zix code map file:line (tools/zix + tests + flake wiring). E2 explore: machine0 repo + upstream machine0-nixos clone + hermes skill. L1-L4 librarian: Railway docs/template format; nix-in-containers prior art & constraints; eval-cost reduction (eval-cache, multiverse, attic/cachix); reference repos (bon5co, moraxyc, multiverse, omnibin) SHA-pinned. B1-B2 browsing (ultimate-browsing): railway.com deploy/template pages rendered + screenshots; docs.machine0.io rendered. R1 repo-dive: clone bon5co/deepseek-harness-railway + moraxyc/deepseek-harness.nix + fzakaria/nixpkgs-multiverse, pin SHAs, extract recipes.

## Success criteria (binding)
SC1 zix integration lands in machine0 as working, evaluated code (nix flake check clean; runtime-install path demonstrated by execution).
SC2 omo-ai 5.1.22 packaging builds (nix build .#omo or buildNpmPackage equivalent) and omo --version reports 5.1.x.
SC3 Railway template artifact exists (repo + Dockerfile + railway.json + manifest.json + README), image builds locally, and measured: image size, idle RAM, cold + warm install latency for a package and a pinned version.
SC4 Local auth gate proof: unauthenticated request -> 401; healthcheck -> 200.
SC5 machine0 slimming/speed plan validated by concrete measurements/limits (not prose).
SC6 SYNTHESIS.md + report.html delivered; every claim cited; gates run (static/layout/visual/proofread) with statuses in outcome.json; outcome verify passes.
SC7 journal/claim-graph/intent-diff/observation-manifest maintained in real time; team deleted; lanes terminal.

## Deliverable
lane: no-format (chat + repo artifacts); state: new
formats: (1) machine0 repo changes; (2) railway template repo files; (3) SYNTHESIS.md; (4) report.html
destination: this session + on-disk repos; audience: the operator (mei/Nathan); answered_by: request for the artifact list; user-question pending (zix scope, railway agent, home dir, live-deploy) - defaults shown in the question, folded in when answered.

## Expected truths (seed for intent-diff.md)
T1 omo-ai 5.1.22 is latest non-beta and packages under node>=24 (buildable via buildNpmPackage).
T2 A Railway template = image + manifest; publishing requires the railway.com template flow; TemplateCI validates manifests.
T3 The reference nix flavor runs ~135 MiB idle and needs >=1 GB because nixpkgs eval spikes ~590 MB; a no-eval install path would lower this.
T4 m0-coding v3 is 38.39 GB with 80 GB min disk; lighter is possible (trimming closures/angles TBD).
T5 zix today edits repo files + pins; it is NOT a runtime installer; runtime installs are the gap for 'whenever they want'.
T6 multiverse fast path can install a package version without evaluating nixpkgs (claim to verify by execution).
T7 Railway containers have no /dev/fuse and may lack user namespaces; nix sandbox must be disabled or userns available (verify).
T8 The user's Railway account can validate a deploy end-to-end if asked; machine0 API is currently inaccessible (not logged in).

## Constraints
- Do not spend money / create cloud resources without an explicit user answer (live deploy + machine0 VMs).
- Do not write to /home/mei/machine0 or /home/mei/nixos git history without a commit decision; keep worktrees clean per task.
- Instrumentation files are orchestrator-owned; workers return text only.