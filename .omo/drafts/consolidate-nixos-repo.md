---
slug: consolidate-nixos-repo
status: drafting
intent: clear
review_required: true
plan_path: .omo/plans/consolidate-nixos-repo.md
plan_sha256: null
review_round_id: null
pending-action: write and review .omo/plans/consolidate-nixos-repo.md
review:
  momus:
    status: pending
    workspace_root: null
    runtime_home: null
    target: .omo/plans/consolidate-nixos-repo.md
    round_id: null
    plan_sha256: null
    launch_id: null
    session: null
    result: null
  independent:
    status: pending
    workspace_root: null
    runtime_home: null
    target: .omo/plans/consolidate-nixos-repo.md
    round_id: null
    plan_sha256: null
    launch_id: null
    session: null
    result: null
approach: Merge ~/nix-config into this repo, rename the repo to nixos/, apply a new host-naming scheme, and remove the manual-ssh install scripts in favor of a flake-built custom ISO + nixos-anywhere + deploy-rs pipeline.
---

# Draft: consolidate-nixos-repo

## Components (topology ledger)
<!-- Lock the SHAPE before depth. One row per top-level component that can succeed or fail independently. -->
<!-- id | outcome (one line) | status: active|deferred | evidence path -->
- C1 | repo-merge: absorb sibling nix-config (darwin + standalone-linux trees) into this repo | active | /home/mei/nix-config/
- C2 | repo-rename: rename directory + repo to `nixos`, update git remote, rewrite name refs | active | .git/config; grep refs
- C3 | host-rename: apply antagony/remembrance/entropy/massive naming across authority+aspects+apps+tests | active | modules/entities/_machine-authority/model.nix
- C4 | script-removal: delete manual-ssh install scripts, rewire dependent tests/docs | active | bin/*; tests/readiness/*; docs/service-notes/*
- C5 | iso-pipeline: create flake ISO-builder target + deploy-rs integration (the "next" the user wants) | active | modules/flake/apps.nix (none today)

## Open assumptions (announced defaults)
<!-- Record any default you adopt instead of asking, so the user can veto it at the gate. -->
<!-- assumption | adopted default | rationale | reversible? -->
- Merge history default | Fresh repo / single root commit (copy B's files into A's tree, resolve dupes once, commit). NOT --allow-unrelated-histories (both repos share too much; history valueless for deploy-rs/Hydra — Hydra deletes .git) | Research-backed; user re-creates on own mirror anyway | Not easily reversible (history dropped)
- Script retention | KEEP nix-config-hardware-collector/-intake (hardware-intake, not install) and setup-noctalia-cachix.sh (daemon cache, not install); DELETE the 6 manual-ssh install scripts + 2 shims | Explorer verified these are not install workflows and are independently tested | Reversible (git history)
- Boundary-test handling | UNION both repos' boundary tests and INVERT the negative cross-repo assertions to positive (this is BOTH the darwin-negatives in A AND the standalone-linux-negative at tests/dendritic-boundaries.sh:20-23 AND the parent-path existence check) | METIS A2: A's own boundary test asserts modules/standalone-linux/home-manager.nix and modules/darwin/ must NOT exist — after merge they DO | Reversible
- flake input union | Take A's flake.nix (has disko), add darwin input from B; both pin den to same rev 1614f6f8 | A is receiver; B's darwin input is the only new one | Reversible
- file-union not file-copy for 5 divergent files | modules/linux/home-manager.nix, config/package-exceptions.json, modules/aspects/features/{desktop-media,device-capability-routing}.nix, tests/dendritic-* differ between repos — merge/union per-file with a documented contract, NOT bit-for-bit copy | METIS A1/A4/D1/D2/D3 falsified "bit-for-bit" claims; B's linux/home-manager.nix is uncommitted-dirty | Revertible
- .sops.yaml / .gitignore | ADD from B (A has neither) | METIS A3: A lacks both files | Revertible
- enrollment writer after script drop | Keep an enrollment path alive: the ISO flow writes model.nix declaratively per-host (bake enrollment into the target's model.nix record + build ISO); do NOT leave the four-enrollment gate with zero writers | METIS B3: deleting nix-config-install removes the only model.nix enrollment writer | Revertible
- temp stub hosts | Move "temp stubs for future servers" OUT of scope (only the 4 named hosts exist) | METIS C1: pure expansion; only antagony/remembrance/entropy/massive are real | N/A

## Findings (cited - path:lines)
- Sibling exists at /home/mei/nix-config (git remote github.com/meillaya/nix-config.git); NOT a submodule (no .gitmodules). Layout: modules/darwin/, modules/standalone-linux/, apps/aarch64-darwin/, pkgs/omniwm.nix, darwin aspects under modules/aspects/. [explorer bg_0ad7e17e]
- Current repo /home/mei/NixOS-config (remote github.com/meillaya/NixOS-config.git) owns modules/nixos/, modules/linux/, modules/shared/, and only a stub modules/standalone-linux/config/noctalia/. [explorer bg_0ad7e17e]
- Host authority in modules/entities/_machine-authority/model.nix: nixos-laptop (x86_64-linux, workstation), nixos-x86-qualifier (qualifier), aarch64-linux (evaluation); sibling adds aarch64-darwin (mac, workstation, uid 501, /Users/mei). validators.nix:407-432 hardcodes hostId→target→system→role; scripts/hardware/contracts.py:30 + collector.py:20-23 duplicate these routes. [explorer bg_ab3f9b05]
- NO ISO-builder flake target exists. apps.nix registers only build/clean/switch/update/nh. isoArtifactSizeBytes/isoSha256 manifest fields exist only as scaffolding in scripts/readiness/task7/contracts.py:776-777,840-842 and config/install/manifest.schema.json. [explorer bg_84832651]
- ALL bin/ install scripts are manual-ssh (nixos-anywhere-over-SSH): nix-config-install (build via nh + nixos-anywhere over SSH, L265-308), install-direct/install-remote (shims), nixos-anywhere-bootstrap-password.{sh,fish}. Test dependencies: tests/readiness/task7/run_case.py (N19/N20), tests/bootstrap-password-*.sh, tests/readiness/task15/*. [explorer bg_84832651]
- Boundary tests in BOTH repos assert the OTHER must not contain certain trees; both must be inverted after merge. tests/dendritic-boundaries.sh:17-27, dendritic-architecture.sh:65-81,143-153 (A); nix-config/tests/dendritic-architecture.sh:55-83,145-154 (B). [direct reads]
- Darwin references in A are 183 matches/33 files but mostly NEGATIVE guards; after merge they become positive. [explorer bg_0ad7e17e]
- Rename surface: 46 text + 14 Python matches for "nix-config/NixOS-config" in A, 16 in B; plus modules/nixos/system.nix:35, modules/aspects/users/mei.nix:55, __pycache__/*.pyc, .codegraph symlink. [explorer bg_0ad7e17e]
- Research: build ISO via `nix build .#iso.<host>` = nixosConfigurations.<host>.config.system.build.isoImage (or system.build.images.iso-installer / nixos-rebuild build-image --image-variant iso-installer); nixos-generators is ARCHIVED (25.05 upstreamed). nixos-anywhere auto-detects VARIANT_ID=installer and skips kexec when booted from custom ISO. deploy-rs: deploy.nodes.<host> + checks=builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib. [librarian bg_b4df3404]
- Git merge: fresh repo + single commit recommended; history valueless for deploy/Hydra. [librarian bg_a7643ef1]

## Decisions (with rationale)
- D1: Merge via fresh root commit (copy B files into A tree, resolve dupes once). Rationale: research-backed; user re-creates on mirror.
- D2: Host naming is LOCKED (3-round resolution): nixos-laptop→remembrance (NixOS, this PC), antagony=new 2nd NixOS workstation (P52, modeled on nixos-laptop), massive=standalone-linux HM host, entropy=aarch64-darwin, drop nixos-x86-qualifier+aarch64-linux.
- D3 (METIS): Do NOT treat 5 files as bit-for-bit — merge/union per-file with a contract: modules/linux/home-manager.nix, config/package-exceptions.json, modules/aspects/features/desktop-media.nix + device-capability-routing.nix, tests/dendritic-*.sh.
- D4 (METIS): Keep an enrollment path alive after deleting install scripts (declarative model.nix write per-host in the ISO flow).
- D5 (METIS): Add .sops.yaml + .gitignore FROM B (A lacks both).
- D6 (METIS): "temp stub hosts for future servers" is OUT of scope.

## Scope IN
- Merge sibling darwin + standalone-linux trees; reconcile flake.nix inputs (add darwin); dedup bit-for-bit shared files; invert boundary tests.
- Rename repo dir + git remote to `nixos`; rewrite all name references; regenerate .codegraph; rm __pycache__.
- Apply new host naming (antagony/remembrance/entropy/massive + temp stubs for future servers) across model.nix, validators.nix, hosts.nix, named-hosts/storage/hardware aspects, apps, tests, docs, python routing tables.
- Remove the manual-ssh install scripts; create the ISO-builder flake target; wire deploy-rs for day-2.

## Scope OUT (Must NOT have)
- NO migration of the CachyOS desktop's pacman/AUR packages into this repo (the entropyos-cachyos audit doc is informational only for now; `massive` is CachyOS-with-nix, not a NixOS host we own yet).
- NO x86_64-darwin output (retired).
- NO rewrite of upstream nixos-anywhere/deploy-rs code; only flake integration.
- NO touching the sibling repo's secrets beyond dedup of coding-agents.yaml (keep the tracked sops-encrypted copy; .sops.yaml recipients are already the same age keys).
- NO running `nix flake check` against the live cluster; evaluation/build is agent-executed in the sandbox only.

## Open questions
RESOLVED.
- Q1 (RESOLVED by user, three rounds): Host mapping locked —
  - **remembrance** = THIS PC (the machine running this session), currently CachyOS/Arch but user is DITCHING Arch → becomes a **NixOS** workstation. Maps to current `nixos-laptop` machine record (the repo's only NixOS workstation today). Real NixOS host.
  - **antagony** = ThinkPad P52 laptop, currently CachyOS → becomes a **NixOS** workstation. **NEW** second NixOS host, modeled on the `nixos-laptop` machine record (stub to be hardware-enrolled later). Real NixOS host.
  - **massive** = the OTHER/non-NixOS desktop, CachyOS + nix package manager → maps to the **standalone-linux Home-Manager** host (x86_64; `modules/standalone-linux` + `modules/linux`). NOT a NixOS host. This is the standalone HM host in the merged repo.
  - **entropy** = mac mini → `aarch64-darwin` (darwinConfigurations).
  - **nixos-x86-qualifier** and **aarch64-linux** (eval hosts) → **DROPPED**.
- Q2 (RESOLVED by user): YES to the 6-delete/3-keep script split.

## Approval gate
status: awaiting-approval
<!-- When exploration is exhausted and unknowns are answered, set status: awaiting-approval on approval; review runs after plan is written. -->
- APPROVED by user (explicit "Approve").
- Plan written: .omo/plans/consolidate-nixos-repo.md (21 implementation todos + 4 final-verifier rows; every todo has References/Acceptance/QA/Commit + executor category; TL;DR filled last).
- review_required: true → dual high-accuracy review.
- Round 1: momus CHANGES_REQUESTED (2 P0 + 2 P1: config-eval.nix pre-merge topology; dendritic-apps.sh aarch64-linux; dendritic-architecture.sh:188; wrong device-capability-routing path). oracle CHANGES_REQUESTED (3 P0 + 3 P1 + 10 P2: union-add merge direction; phantom todos 22/23; systems.nix aarch64-darwin; enrollment-writer test; massive node name; boundary collision; + minors). ALL findings applied to the plan.
- Round 2: momus CHANGES_REQUESTED (1 residual: Todo 5 wrong path device-capability-routing still in features/ — FIXED to hardware/). oracle CHANGES_REQUESTED (2 must-fixes: dependency matrix phantom 22 in rows 7/10-17 + row 4 Blocks mismatch — FIXED; P1-1 acceptance used nonexistent `nix-config-hardware-intake --fixture` → FIXED to `validate` subcommand; + non-blocking: Todo 20 Parallelization line added). ALL applied.
- Round 3: momus **APPROVE** (unconditional) — all 3 round-2 findings verified resolved; every referenced file exists; decision-complete + sandbox-feasible. oracle **APPROVE** (unconditional) — independently verified CLI surface (`nix-config-hardware-intake validate <fixture> <model.nix>` matches cli.py), systems.nix pin, dependency matrix (no phantom 22, row 4 Blocks matches todo 4), 21 todos + F1-F4 present/column-zero/executor-annotated; one benign non-blocking matrix row-3 note.
- **Dual high-accuracy review COMPLETE — BOTH PASSES APPROVE.** Receipts: momus round-3 = APPROVE (session ses_fd1e10276ffevM17LSwGvT935R, bg_d5b8a8a1); oracle round-3 = APPROVE (session ses_fd1e0fa2effecC1P2xGWVeQMdL, bg_9991ef5a).
- Final live-plan validation: .omo/plans/consolidate-nixos-repo.md SHA-256 matches the approved round digest; both reviewers read the exact path.
