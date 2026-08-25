# consolidate-nixos-repo - Work Plan

## TL;DR (For humans)
<!-- Fill this LAST, after the detailed plan below is written, so it summarizes the REAL plan. -->
<!-- Plain English for a non-engineer: NO file paths, NO todo numbers, NO wave/agent/tool names. -->

**What you'll get:** One unified Nix flake repo (`nixos/`) that owns all four machines — remembrance (this PC, becoming NixOS), antagony (a ThinkPad, also becoming NixOS), entropy (a Mac mini), and massive (a CachyOS/Arch desktop that stays on Home Manager) — a renamed git remote, the manual SSH-based install scripts removed, and a proper flake-built install ISO plus a day-two deploy tool wired in.

**Why this approach:** You were duplicating shared config across two repos (NixOS-config + nix-config) by hand, which had already drifted. Merging into one repo with a single root commit and a fresh remote is the lowest-risk path because your deploy tools (deploy-rs and Hydra) read the file tree, not git history. A flake-built ISO + nixos-anywhere replaces the SSH-based installer flow you're retiring.

**What it will NOT do:** It will not migrate the CachyOS/Arch desktop's packages into NixOS — `massive` stays on its own package manager and only gets Home Manager. It will not invent stub hosts for future servers (only the four real machines are created). It will not rewrite upstream nixos-anywhere or deploy-rs code, and it will not run the real cluster builds.

**Effort:** Large
**Risk:** High - this renames a live desktop machine's identity and deletes its enrollment tooling; the merge touches ~30 host-wiring points and 5 files that already differ between repos.
**Decisions to sanity-check:** host mapping (remembrance=this PC as NixOS), the 6-delete/3-keep script split, keeping one model.nix enrollment path alive, and adopting B's `.sops.yaml`/`.gitignore`.

Your next move: run the high-accuracy review (momus + independent oracle) which you requested, then hand off for execution via `/start-work`.

---

> TL;DR (machine): Large, Medium risk. Merge sibling repo, rename to `nixos/`, remap 4 hosts, drop 2 eval hosts, remove 6 manual-ssh install scripts, add flake ISO target + deploy-rs; commit once; run the verification wave.

## Scope
### Must have
- Merge the sibling `~/nix-config/` (Darwin + standalone-Linux trees) into this repo as a fresh root commit.
- Rename the repo directory + git remote to `nixos`; rewrite every name reference.
- Apply the locked host mapping across machine authority, aspects, apps, tests, and Python routing tables:
  - `nixos-laptop` → `remembrance` (NixOS workstation, this PC)
  - new `antagony` NixOS workstation (ThinkPad P52, modeled on `nixos-laptop`)
  - `massive` = standalone-linux Home-Manager host (x86_64)
  - `aarch64-darwin` → `entropy`
  - drop `nixos-x86-qualifier` + `aarch64-linux`
- Delete the 6 manual-ssh install scripts (`nix-config-install`, `nix-config-enroll`, `install-direct`, `install-remote`, `nixos-anywhere-bootstrap-password.sh` + `.fish`); keep `nix-config-hardware-collector`, `nix-config-hardware-intake`, `setup-noctalia-cachix.sh`.
- Add an ISO-builder flake target (`.#iso.<host>` → `system.build.isoImage`) and deploy-rs wiring (`deploy.nodes` + `deployChecks`).
- Keep one model.nix enrollment path alive (declarative per-host write) so the four-enrollment trust gate still has a writer.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- NO "temp stub hosts for future servers" — only the 4 named hosts (antagony, remembrance, entropy, massive) are created.
- NO migration of `massive`'s CachyOS/Arch packages into Nix (it stays on its package manager; only Home Manager).
- NO `x86_64-darwin` output (retired).
- NO rewrite of upstream nixos-anywhere/deploy-rs; flake integration only.
- NO pushing to the live Proxmox cluster from this plan; builds are sandbox-only.
- NO auto-build of the Darwin host in this plan (entropy is declared, not activated).
- NO multi-ISO matrix — exactly ONE ISO variant (installer) per host.
- NO silent "rewire" of dependent tests/docs — each is explicitly delete-or-rewrite (see todos).
- NO Docker / flake registry edits / CI push work beyond what is enumerated.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: tests-after. The repo has a large existing shell/Python test suite (`tests/dendritic-*.sh`, `tests/readiness/*`, `tests/package-policy.sh`) that is the acceptance harness; changes must keep them green.
- Evidence: `.omo/evidence/ulw/<session>/<goalId>/a<attempt>` for each task. Every todo records its happy + failure QA scenario with the exact command and expected assertion.
- Master gate (run after all todos, in the final wave):
  - `nix flake check --all-systems --no-build` → passes on the merged root (x86_64-linux, aarch64-darwin eval)
  - `bash tests/dendritic-architecture.sh && bash tests/dendritic-boundaries.sh && bash tests/dendritic-apps.sh && bash tests/package-policy.sh` → all green
  - `grep -R -n --exclude-dir=.git --exclude-dir=.omo -E 'nix-config|NixOS-config|nixos-x86-qualifier|aarch64-linux' .` → **0 matches** (post-rename)
  - `python3 -m pytest tests/readiness/task15 tests/readiness/task17 scripts/hardware` → passes post-rename
  - `nix build '.#nixosConfigurations.x86_64-linux.config.system.build.isoImage'` → succeeds (ISO builder works)
  - `nix eval --impure --json --expr 'builtins.getFlake "path:." | .deploy.nodes'` → shows antagony/remembrance/entropy/massive nodes

## Execution strategy
### Parallel execution waves
- **Wave 1 — Staging & safety (blocking):** snapshot B working tree (commit or discard the dirty `linux/home-manager.nix`), back up remote refs, capture machine-authority model + secrets integrity. (Todos 1-2)
- **Wave 2 — Merge tree (core, blocking for everything below):** fresh-root-commit B's files into A, union flake.nix inputs (add `darwin`), union `den.hosts`/`den.homes`, union per-file the 5 divergent files, add `.sops.yaml`+`.gitignore`, invert boundary tests. (Todos 3-7)
- **Wave 3 — Rename repo:** rename dir → `nixos`, git remote → `.../nixos.git`, rewrite 60+ name references, rm `__pycache__/*.pyc`, regenerate `.codegraph`. (Todos 8-9)
- **Wave 4 — Host remap:** apply antagony/remembrance/entropy/massive across machine-authority, named-hosts/storage/hardware aspects, inventory, flake outputs, apps, python route tables, tests, docs; drop the 2 eval hosts' wiring. (Todos 10-17)
- **Wave 5 — Script removal + ISO/deploy-rs pipeline:** delete the 6 install scripts; rewrite/delete their dependent tests/docs; add ISO-builder target; wire deploy-rs. (Todos 18-21)
- **Wave 6 — Verification + final wave.**

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 3 (union-add merge) | 1,2 | 4,5,6,7,8,9 | 4 with 5 |
| 4 (union flake.nix) | 3 | 7,8 | 5 |
| 5 (union 5 files) | 3 | 6 | 4 |
| 6 (add .sops/.gitignore) | 3 | 7 | 5 |
| 7 (invert boundary tests) | 3 | 17,21 | 6 |
| 8 (rename dir+remote) | 3 | 9 | 7 |
| 9 (rewrite name refs) | 8 | 10,11,12,13,14,15,16,17 | 7 |
| 10-17 (host remap) | 9 | 21 | 11,12,13,14,15,16 parallel |
| 18-21 (scripts+ISO+deployrs) | 17,10 | 21 | 18,20 with 19 |
| 21 (final test gate) | all | none | - |

## Todos
> Implementation + Test = ONE todo. Never separate.

- [x] 1. Stage the sibling working tree (snapshot + dirty-file decision)
  What to do / Must NOT do: Commit-or-discard B's uncommitted `modules/linux/home-manager.nix` BEFORE copy. Snapshot B's remote refs (record `origin` URL + current HEAD sha) so the merge never silently destroys history it needs to keep. Do NOT force-push an orphan root over `github.com/meillaya/NixOS-config.git` without the snapshot recorded.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 2,3,9
  References: /home/mei/nix-config (B repo); B `.git/config` (remote https://github.com/meillaya/nix-config.git); METIS A1 line 511-515 (B dirty).
  Acceptance criteria: A file `.omo/evidence/consolidate-nixos-repo/merge-snapshot.json` exists recording B origin HEAD + dirty-file list; `git -C /home/mei/nix-config status --short` shows no unstaged `modules/linux/home-manager.nix` (committed or discarded).
  QA scenarios:
   - happy: snapshot file written; B `status --short` clean.
   - failure: B still shows ` M modules/linux/home-manager.nix` → abort before copy.
  Evidence: .omo/evidence/consolidate-nixos-repo/task-1-consolidate-nixos-repo.json
  Commit: N | chore(nix-config): snapshot sibling before merge
  Recommended task executor category: quick (mechanical snapshot; no code reasoning)

- [x] 2. Back up current A remote refs and secrets
  What to do / Must NOT do: Capture `.git/config` origin URL + remote refs, and the tracked `secrets/coding-agents.yaml` + `.sops.yaml` (B) into a side file before any destructive step. Do NOT decrypt or print secrets; just reference their paths + the sops header.
  Parallel: Wave 1 | Blocked by: 1 | Blocks: 8
  References: `/home/mei/NixOS-config/.git/config`; `secrets/coding-agents.yaml`.
  Acceptance: a `.omo/evidence/consolidate-nixos-repo/remote-and-secrets-backup.json` records remote URL + that `secrets/coding-agents.yaml` sops header matches B's admin key.
  QA: happy → file written; failure → script exits nonzero if `.git/config` unreadable.
  Evidence: .omo/evidence/consolidate-nixos-repo/task-2-consolidate-nixos-repo.json
  Commit: N | tracker: backup remote+secrets
  Recommended task executor category: quick (mechanical backup file)

- [x] 3. Union-add sibling working tree into this repo (fresh-root commit)
  What to do / Must NOT do: Copy B's working tree (tracked files) into A's tree as a **union-add**: add every B file that A lacks; **NEVER overwrite an existing A file** — every path that exists in BOTH repos is left as A's version for todo 5 to reconcile. EXCLUDE from the copy: `.git/`, `.omo/`, `.codegraph/`, `__pycache__/`, `result/`, `secrets/*` (except tracked `coding-agains.yaml` + README). Delete the sibling's git metadata so no nested repo. Then `git add -A` + a fresh root commit (or `git init` + first commit). Do NOT use `--allow-unrelated-histories`; this is a fresh-root union copy. Do NOT `cp -r` over A; use a union-copy (e.g. `cp -rn` or rsync without `--delete`).
  Parallel: Wave 2 | Blocked by: 1,2 | Blocks: 4,5,6,7,8
  References: B tree at /home/mei/nix-config; A tree at /home/mei/NixOS-config; `.gitignore` (B: `secrets/*`, `__pycache__/`, `*.py[cod]`, `result`); METIS A1/A3; ORACLE P0-1.
  Acceptance: after copy, `ls modules/` shows `darwin/`, `standalone-linux/`, `nixos/`, `linux/`, `shared/`, `entities/`, `aspects/`, `flake/` present; A's pre-existing files are NOT clobbered (e.g. `modules/linux/home-manager.nix` still equals A's version until todo 5); a `.gitignore` (from B) is present.
  QA happy: `test -d modules/darwin && test -d modules/standalone-linux && test -f .gitignore` → pass; `diff modules/linux/home-manager.nix "${SNAPSHOT_OF_A_BEFORE_MERGE}"` → identical to A's pre-merge version.
  QA failure: `git ls-files modules/darwin` empty after copy → script errors; `modules/linux/home-manager.nix` shows B's content → the union-add overwrote A (must stop).
  Evidence: .omo/evidence/consolidate-nixos-repo/task-3-consolidate-nixos-repo.json
  Commit: Y | build(nixos): merge sibling repo as fresh root (union-add)
  Recommended task executor category: deep (destructive tree-merge; must reason about what to exclude)

- [x] 4. Union `flake.nix` inputs (add `darwin`, keep `disko`)
  What to do / Must NOT do: Take A's `flake.nix` (receiver) and add B's `darwin` input (`url = "github:LnL7/nix-darwin/master"` with `nixpkgs.follows`). Keep A's `disko` input and the `den` pin. Remove any duplicate input keys. Keep `emacs-overlay`, `sops-nix`, `home-manager`, `zen-browser`, `spicetify-nix`, `helium`, `noctalia`, `stylix`, `nix-direnv`, `nh`, `preservation`, `den`, `flake-parts`, `import-tree` from whichever repo is the canonical copy.
  Parallel: Wave 2 | Blocked by: 3 | Blocks: 7,8
  References: A `flake.nix` (has disko, den pin); B `flake.nix` (has darwin, den pin same rev). METIS D4/D5 verified same revs.
  Acceptance: `grep -Fq 'darwin.url' flake.nix` and `grep -Fq 'github:LnL7/nix-darwin' flake.nix`; `grep -Fq 'github:nix-community/disko' flake.nix`; no duplicate input keys (eval passes).
  QA happy: `nix eval --impure --expr '(builtins.getFlake "path:.").flake.inputs'` lists darwin + disko.
  QA failure: duplicate input key → eval errors; grep finds duplicate.
  Evidence: .omo/evidence/consolidate-nixos-repo/task-4-consolidate-nixos-repo.md
  Commit: Y | feat(nixos): union flake inputs (add darwin, keep disko)
  Recommended task executor category: unspecified-high (multi-file flake reconciliation)

- [x] 5. Union the 5 divergent files per-file (NOT bit-for-bit)
  What to do / Must NOT do: For each of `modules/linux/home-manager.nix`, `config/package-exceptions.json`, `modules/aspects/features/desktop-media.nix`, `modules/aspects/hardware/device-capability-routing.nix`, and `tests/dendritic-*.sh`: compare A vs B, take the CORRECT union (not a blind copy). For `linux/home-manager.nix`, B's version is NEWER (removed Sweet-Dark theme; A is older with Sweet) → take B's + its uncommitted edits. For `package-exceptions.json`, union BOTH exception sets (B adds darwin/raycast; A adds aarch64-linux eval exceptions — but aarch64-linux is dropped, so keep only the surviving systems' exceptions). Do NOT copy a divergent file blindly.
  Parallel: Wave 2 | Blocked by: 3 | Blocks: 6
  References: METIS A1/A4; diff A/B of each file (verified: only linux/home-manager.nix differs in modules/linux; package-exceptions differs; desktop-media + hardware/device-capability-routing differ; dendritic-* differ).
  Acceptance: `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'` passes (proves flake/nix files merge cleanly); `nix flake check --no-build` passes.
  QA happy: `diff modules/linux/home-manager.nix /home/mei/nix-config/modules/linux/home-manager.nix` → empty (B taken).
  QA failure: leftover `Sweet-Dark` in `modules/linux/home-manager.nix` → the A copy was used by mistake.
  Evidence: .omo/evidence/consolidate-nixos-repo/task-5-consolidate-nixos-repo.md
  Commit: Y | fix(nixos): union divergent shared files (take B's linux HM, union exceptions)
  Recommended task executor category: deep (per-file merge decisions across 5 divergent files)

- [x] 6. Add `.sops.yaml` + `.gitignore` from B (A has neither)
  What to do / Must NOT do: Copy B's `.sops.yaml` and `.gitignore` into the merged root. Verify the age keys in `.sops.yaml` match the recipients embedded in `secrets/coding-agents.yaml` (they do — same admin key). Do NOT create a new/empty `.sops.yaml`; take B's.
  Parallel: Wave 2 | Blocked by: 3 | Blocks: 7
  References: B `.sops.yaml`; B `.gitignore`; A has neither (METIS A3).
  Acceptance: `grep -Fq "age1xxj3ft4g9gkfryedx85z9je76s07xxfqcvzl4c3t777d45hfgpvqwkpclc" .sops.yaml`; `grep -Fq "secrets/*" .gitignore`; `ls -la .gitignore .sops.yaml` both present.
  QA happy: both files exist with correct content.
  QA failure: `.sops.yaml` missing → secrets can't be re-encrypted.
  Evidence: .omo/evidence/consolidate-nixos-repo/task-6-consolidate-nixos-repo.md
  Commit: Y | chore(nixos): add .sops.yaml + .gitignore from merged repo
  Recommended task executor category: quick (copy two files, verify keys)

- [x] 7. Invert boundary tests (both repos' negatives → positive) + rewrite `dendritic-config-eval.nix` for the merged topology
  What to do / Must NOT do: Todo 3's union-add guarantees A's `tests/dendritic-boundaries.sh` survives (B's colliding same-path file is NOT copied over it — ORACLE P1-3). So in the merged tree: (1) in `tests/dendritic-boundaries.sh`, flip the checks so `modules/standalone-linux/home-manager.nix` and `modules/darwin/` MUST EXIST (currently assert must-not: lines 20-26), and remove the B-only `$root/../NixOS-config` parent-path existence check (no more sibling). (2) In `tests/dendritic-architecture.sh`, remove the "must NOT contain Darwin" and "must declare no nixosConfigurations" negatives and replace with positives for the merged graph; also remove/replace the positive `aarch64-linux` assertion at line 188. (3) ADDITIONALLY (Momus P0): rewrite `tests/dendritic-config-eval.nix` to assert the merged post-remap topology: `nixosConfigurations == [ "antagony" "remembrance" ]`, `darwinConfigurations == [ "entropy" ]`, `homeConfigurations == [ "standalone-linux" ]`, `machineIds == [ "antagony" "entropy" "remembrance" ]`, and update the hostname/app-surface assertions at lines 124-126, 133-140, 153-158 (currently assert old hosts + empty darwin/homeConfigurations). Do NOT invert a check that is unrelated to the merge.
  Parallel: Wave 2 | Blocked by: 3 | Depends: 6 | Blocks: 17,21
  References: A `tests/dendritic-boundaries.sh:17-26`; A `tests/dendritic-architecture.sh:65-81,143-153,188`; A `tests/dendritic-config-eval.nix:124-126,133-140,153-158`; B `tests/dendritic-boundaries.sh:18-22`; METIS A2; MOMUS P0/P1 (tool_02e16ed64001xYZ56oq7PQlOx1); ORACLE P1-3.
  Acceptance: `bash tests/dendritic-boundaries.sh` exits 0; `bash tests/dendritic-architecture.sh` exits 0; `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'` prints `dendritic-config-eval=PASS`.
  QA happy: all three scripts print their `PASS` lines.
  QA failure: any of the three exits nonzero (asserts old topology) → re-check the rewrite.
  Evidence: .omo/evidence/consolidate-nixos-repo/task-7-consolidate-nixos-repo.md
  Commit: Y | test(nixos): invert boundary + rewrite config-eval for merged topology
  Recommended task executor category: unspecified-high (flip multi-condition test logic)

- [x] 8. Rename repo dir + git remote to `nixos`
  What to do / MUST NOT do: Rename the working directory from `NixOS-config` to `nixos` (or equivalent; a new remote). Update `.git/config` origin URL → `https://github.com/meillaya/nixos.git` (or your mirror URL). Do NOT push yet. Keep a git-ignored `.bootstrap` file capturing the old remote if needed. Update `modules/nixos/system.nix:35` nixPath `nixos-config=${home}/.local/share/src/nixos-config` → the new `nixos` name (see Wave 4) — actually this is the runtime path; leave a note, but the rename is the dir.
  Parallel: Wave 3 | Blocked by: 3 | Depends: 2 | Blocks: 9
  References: `.git/config` (origin URL now `.../NixOS-config.git`); `modules/nixos/system.nix:35`.
  Acceptance: `grep -Fq "url = https://github.com/meillaya/nixos.git" .git/config`; `git remote get-url origin` returns the new URL.
  QA happy: remote URL updated, dir named `nixos`.
  QA failure: remote still points at `NixOS-config.git`.
  Evidence: .omo/evidence/consolidate-nixos-repo/task-8-consolidate-nixos-repo.md
  Commit: Y | chore(nixos): rename repo dir + remote
  Recommended task executor category: quick (single .git/config edit + dir rename)

- [x] 9. Rewrite every name reference (60+ occurrences)
  What to do / Must NOT do: Replace all references to `nix-config`/`NixOS-config`/`nixos-config` with `nixos` across the merged tree (README, modules, docs, tests, config/*.json, apps, scripts, `modules/nixos/system.nix:35` nixPath, `modules/aspects/users/mei.nix:55` codex shim, `standalone-linux/home-manager.nix:23`). Delete `__pycache__/*.pyc` (regenerate). Regenerate `.codegraph` symlink (point at `nixos-...` project). Do NOT rename identifiers of machine hostnames (that's Wave 4); only the REPO name.
  Parallel: Wave 3 | Blocked by: 8 | Depends: 7 | Blocks: 10
  References: METIS findings: 46 text + 14 py in A, 16 in B; `modules/nixos/system.nix:35`, `modules/aspects/users/mei.nix:55`, `standalone-linux/home-manager.nix:23`, `.codegraph`, `__pycache__`.
  Acceptance: `grep -R -n --exclude-dir=.git --exclude-dir=.omo -E 'NixOS-config|nix-config|nixos-config' .` → **0 matches** (repo-name only).
  QA happy: 0 matches.
  QA failure: any remaining `NixOS-config` in codex shim or docs.
  Evidence: command output saved in evidence dir.
  Commit: Y | refactor(nixos): rename repo references
  Recommended task executor category: unspecified-high (systematic across ~60 refs)

- [x] 10. Remap `nixos-laptop` → `remembrance` (machine authority + named-hosts/storage/hardware)
  What to do / Must NOT do: In `modules/entities/_machine-authority/model.nix`, rename the `nixos-laptop` key → `remembrance`, hostId `remembrance`, role `workstation`, target `nixosConfigurations.remembrance` (per the host name), system `x86_64-linux`. Update the named-hosts aspect `modules/aspects/named-hosts/nixos-laptop.nix` → `modules/aspects/named-hosts/remembrance.nix` (aspect key `remembrance`), the storage aspect `modules/aspects/storage/nixos-laptop.nix` → `remembrance-storage`, and hardware `modules/aspects/hardware/pending-x86-workstation.nix` referenced from it. Update the `compatibility alias` in `modules/aspects/hosts/nixos-workstation.nix:3` (`den.aspects.x86_64-linux.includes = [ den.aspects.remembrance ];`). Update `modules/entities/hosts.nix` machineFor lookup + `den.hosts` key. Update `scripts/hardware/contracts.py` `_ROUTES` + `collector.py` `ROUTES` entry. Do NOT leave a `nixos-laptop` string.
  Parallel: Wave 4 | Blocked by: 9 | Depends: 7 | Blocks: 11
  References: `modules/entities/_machine-authority/model.nix:5-40`; `modules/aspects/named-hosts/nixos-laptop.nix`; `modules/aspects/storage/nixos-laptop.nix`; `modules/aspects/hardware/pending-x86-workstation.nix`; `modules/entities/hosts.nix`; `scripts/hardware/contracts.py:30`; `scripts/hardware/collector.py`.
  Acceptance: `grep -R -n --exclude-dir=.git -E 'nixos-laptop' modules/ scripts/ tests/` → 0 matches; `nix eval --impure --json --expr '...machineAuthority.machines'` shows key `remembrance`.
  QA happy: eval lists `remembrance`; grep 0 hits.
  QA fail: `nixos-laptop` still found → error.
  Evidence: .omo/evidence/consolidate-nixos-repo/task-10-consolidate-nixos-repo.md
  Commit: Y | feat(nixos): rename nixos-laptop host to remembrance
  Recommended task executor category: deep (machine-authority rename cascades to many aspects)

- [x] 11. Declare new `antagony` NixOS workstation (modeled on remembrance)
  What to do / Must NOT do: Add a NEW machine record to `modules/entities/_machine-authority/model.nix` for `antagony` (ThinkPad P52, x86_64-linux, role workstation, identity mei). Declare the aspect `modules/aspects/named-hosts/antagony.nix` (identical shape to remembrance's), plus `modules/aspects/storage/antagony.nix` and a hardware profile routing (e.g. reuse `pending-x86-qualifier` or a new `antagony`-keyed aspect — follow the existing chain: shared-policy → linux-platform → workstation-role → hardware → storage → named-host). Register it in `modules/entities/hosts.nix` under `den.hosts.x86_64-linux.antagony` (hostName antagony, machine antagony, user mei). Do NOT enroll boot/storage (stay disabled like the current records).
  Parallel: Wave 4 | Blocked by: 10 | Blocks: 14,21
  References: model.nix (existing 3 records pattern); named-hosts/remembrance.nix (template); hosts.nix pattern; METIS B1 for the 30 wiring points.
  Acceptance: `nix eval --impure --json --expr 'builtins.attrNames (builtins.getFlake "path:.").nixosConfigurations'` lists `antagony`; `grep -Fq "antagony" modules/entities/_machine-authority/model.nix`.
  QA happy: eval lists antagony.
  QA fail: eval errors — missing storage or named-host wiring.
  Evidence: evidence file.
  Commit: Y | feat(nixos): declare antagony NixOS workstation
  Recommended task executor category: unspecified-high (new host model + aspects, follows existing pattern)

- [x] 12. Map `massive` → standalone-linux Home-Manager
  What to do / Must NOT do: In `modules/entities/hosts.nix` (merged repo), ensure `den.homes.x86_64-linux.standalone-linux` is wired (from B) and that `massive` is represented as that HM hostname. `massive` has NO machine record in model.nix (METIS D9) — do not fabricate a NixOS machine for it; it stays a standalone home-config only. If `hosts.nix` currently registers `standalone-linux` as a home, keep it and document `massive` = that target. Rename any standalone-linux HM hostname to `massive` if the user's intent is a distinct name — but default: keep the existing `standalone-linux` as the massive home; do NOT create a NixOS `massive`.
  Parallel: Wave 4 | Blocked by: 9 | Depends: 7 | Blocks: 16
  References: B `modules/entities/hosts.nix` (`den.homes.x86_64-linux.standalone-linux`); METIS D9.
  Acceptance: `grep -Fq 'standalone-linux' modules/entities/hosts.nix`; the HM hostname `massive` resolves to standalone-linux config.
  QA: `nix eval --impure --json --expr 'builtins.attrNames (builtins.getFlake "path:.").homeConfigurations'` includes `standalone-linux` (or `massive`).
  Evidence: ...
  Commit: Y | feat(nixos): register massive as standalone-linux home
  Recommended task executor category: unspecified-high (HM host registration + hosts.nix union)

- [x] 13. Map `aarch64-darwin` → `entropy` (darwin host)
  What to do / Must NOT do: In the merged repo, rename the darwin machine `aarch64-darwin` → `entropy` in `modules/entities/_machine-authority/model.nix`, hostId `entropy`, target `darwinConfigurations.entropy`, role workstation. Rename `modules/aspects/named-hosts/aarch64-darwin.nix` → `entropy.nix`. Register in `hosts.nix` under `den.hosts.aarch64-darwin.entropy`. Keep `darwin` system `aarch64-darwin` (the OS/system enum stays `aarch64-darwin`). Do NOT activate build (build-only).
  Parallel: Wave 4 | Blocked by: 9 | Depends: 7 | Blocks: 21
  References: B `modules/entities/_machine-authority/model.nix` (aarch64-darwin), B named-hosts/aarch64-darwin.nix, B hosts.nix.
  Acceptance: `grep -Fq '"entropy"' model.nix`; `grep -Fq 'darwinConfigurations.entropy' hosts.nix`.
  QA happy: eval lists darwin entropy.
  QA fail: `aarch64-darwin` hostId still present.
  Evidence: ...
  Commit: Y | feat(nixos): rename aarch64-darwin → entropy
  Recommended task executor category: deep (darwin host rename cascades across merged darwin surface)

- [x] 14. Drop `nixos-x86-qualifier` + `aarch64-linux` (eval hosts) across ~30 wiring points
  What to do / Must NOT do: Remove `nixos-x86-qualifier` and `aarch64-linux` from: `modules/entities/_machine-authority/model.nix`, `validators.nix:407-432`, `hosts.nix`, `modules/aspects/named-hosts/` (delete the files), `modules/aspects/storage/`, `modules/aspects/hardware/` (pending-x86-qualifier + evaluation-aarch64), `outputs.nix` (`configurationEvaluationPaths` remove), `apps/` (remove `apps/aarch64-linux/` dir + the `if system == "aarch64-linux"` branches in `apps.nix:43,141,176,214,242,387`), `apps/x86_64-linux/build` uname fallback, `apps/x86_64-linux/build-switch` default, `config/package-exceptions.json` (remove aarch64-linux exceptions), `scripts/hardware/contracts.py` + `collector.py` (drop their routes), `tests/readiness/task{15,17,22,23}` aarch64-specific fixtures (KEEP the hardware-intake/preflight parts — see todo 16), `README.md`, `docs/service-notes/wsl-standalone-home-manager.md`. **PIN `modules/flake/systems.nix` to `systems = [ "x86_64-linux" "aarch64-darwin" ]` — remove `aarch64-linux`, ADD `aarch64-darwin`** (the darwin host entropy needs it in the system list for the master gate's aarch64-darwin eval; this is the explicit target, not "drop ONLY if nothing references it"). Do NOT remove `aarch64-darwin` system (that's entropy).
  Parallel: Wave 4 | Blocked by: 9 | Depends: 7 | Blocks: 21
  References: METIS B1 (the ~30 enumerated points). Exactly those paths.
  Acceptance: `grep -R -n --exclude-dir=.git -E 'nixos-x86-qualifier|aarch64-linux' .` → **0 matches** (post-drop); `nix eval --impure --expr 'builtins.getFlake "path:."'` shows `systems.nix` == `["x86_64-linux","aarch64-darwin"]`.
  QA happy: grep 0; eval clean.
  QA fail: `aarch64-linux` still in `apps.nix` conditional or `package-exceptions.json` → grep hits.
  Commit: Y | refactor(nixos): drop eval hosts
  Recommended task executor category: deep (~30 enumerated removal points; needs exhaustive sweep)

- [x] 15. Rewrite `README.md` for the merged repo (no install-script references)
  What to do / Must NOT do: Rewrite README's Install section (currently `bin/nix-config-install --auto`, `bin/nix-config-enroll`, `install-direct`, `install-remote`) to describe the new ISO-driven flow (`nix build .#iso.<host>` + nixos-anywhere). Update the hosts list to the 4 real hosts. Remove references to deleted scripts. Do NOT leave dead install-script commands.
  Parallel: Wave 4 | Blocked by: 9 | Depends: 14 (drops) | Blocks: 21
  References: README.md Install + Hosts sections; METIS C4.
  Acceptance: `grep -F 'bin/nix-config-install' README.md` → no match; `grep -Fq '.#iso.<host>' README.md`.
  QA: README has no reference to deleted bin scripts.
  Commit: Y | docs(nixos): README install flow → ISO
  Recommended task executor category: writing (prose rewrite of install flow + hosts list)

- [x] 16. Rewrite/delete dependent tests for deleted scripts
  What to do / Must NOT do: For each test that references a deleted script: DELETE or REWRITE. Specifically: `tests/readiness/task7/run_case.py` N19/N20 and `test-static.sh` (reference `install-direct`/`install-remote`) → DELETE those cases. `tests/bootstrap-password-{mutations,lifecycle,install-helper,secret-scan}.sh` (reference `nixos-anywhere-bootstrap-password.{sh,fish}`) → DELETE. `tests/readiness/task15/*` (reference `nix-config-hardware-collector`/`-intake` which we KEEP) → KEEP and update paths if needed. `tests/readiness/task22` (references `scripts/readiness/home_preflight.py` — kept). For kept tests that only reference deleted scripts, rewrite to the ISO flow or remove that assertion. Do NOT keep a test asserting a deleted script exists.
  Parallel: Wave 5 | Blocked by: 9 | Depends: 14,15 | Blocks: 21
  References: METIS B4 + list above.
  Acceptance: `pytest tests/readiness/task15 tests/readiness/task17 scripts/hardware` passes; no test file asserts `nix-config-install`/`install-direct`/`nixos-anywhere-bootstrap-password` exists.
  QA: test run green; grep for deleted script names in tests → 0.
  Commit: Y | test(nixos): drop scripts test-deps, keep hardware-intake tests
  Recommended task executor category: unspecified-high (delete-vs-rewrite per test file decision)

- [x] 17. Add the ISO-builder flake target (`.#iso.<host>` → `isoImage`)
  What to do / Must NOT do: In `modules/flake/apps.nix` (or a new `modules/flake/iso-images.nix`), add a per-host `iso` package/app exposing `config.system.build.isoImage` (e.g. `flake.images.<host> = <host>.config.system.build.isoImage`). Wire `isoArtifactSizeBytes`/`isoSha256` into the install-manifest schema (`config/install/manifest.schema.json` and the `scripts/readiness/task7/contracts.py:776-777,840-842` fields) so the manifest validates the built ISO. Do NOT build the actual ISO in this todo (build in a QA/validation step, no push).
  Parallel: Wave 5 | Blocked by: 10 (host remap) | Depends: 9 | Blocks: 20,21
  References: METIS B7 + librarian research: `system.build.isoImage`; `nix build .#nixosConfigurations.x86_64-linux.config.system.build.isoImage`; `flake.images` pattern (NotAShelf/nyx). manifest schema.
  Acceptance: `nix build '.#nixosConfigurations.x86_64-linux.config.system.build.isoImage'` succeeds (dry, sandbox); `nix eval --expr '...config.system.build.isoImage'` resolves; `manifest.schema.json` accepts `isoArtifactSizeBytes`/`isoSha256`.
  QA happy: the ISO build command returns a valid derivation (or a skippable dry-run).
  QA fail: build command errors → fix flake wiring.
  Commit: Y | feat(nixos): ISO-builder flake target
  Recommended task executor category: unspecified-high (flake images wiring + manifest schema)

- [x] 18. Delete the 6 manual-ssh install scripts
  What to do / Must NOT do: Delete `bin/nix-config-install`, `bin/nix-config-enroll`, `bin/install-direct`, `bin/install-remote`, `bin/nixos-anywhere-bootstrap-password.sh`, `bin/nixos-anywhere-bootstrap-password.fish`. KEEP `bin/nix-config-hardware-collector`, `bin/nix-config-hardware-intake`, `bin/setup-noctalia-cachix.sh`. Do NOT delete hardware-collector/intake (they're kept). Remove references to the 6 deleted scripts from all tests (todo 16), docs (todo 15), and the flake if any app references them.
  Parallel: Wave 5 | Blocked by: 16,15 | Depends: 2 (backup) | Blocks: 21
  References: bin/ listing; METIS B036.
  Acceptance: 6 files gone; 3 kept; `grep -R -n -E 'bin/nix-config-install|bin/nix-config-enroll|bin/install-direct|bin/install-remote|bin/nixos-anywhere-bootstrap-password' .` → 0 (except evidence/snapshot).
  QA happy: deleted; kept exist.
  QA fail: a kept test still references a deleted script → grep hits.
  Evidence: ...
  Commit: Y | remove(nixos): delete manual-ssh install scripts
  Recommended task executor category: quick (file deletions + grep verify)

- [x] 19. Wire deploy-rs (`deploy.nodes.<host>` + `deployChecks`)
  What to do / Must NOT do: In the merged flake, add `deploy.nodes` with EXACTLY these names (ORACLE P1-2): `deploy.nodes.remembrance`, `deploy.nodes.antagony`, `deploy.nodes.entropy` (each `profiles.system.path = deploy-rs.lib.<system>.activate.nixos <host>`), and `deploy.nodes.massive` (home-only profile). PIN the node name to `massive` (NOT `standalone-linux`) so the master gate's `deploy.nodes` check passes. Add `checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib`. Add the `deploy-rs` flake input. Do NOT run actual deployments (sandbox eval only).
  Parallelization: Wave 5 | Blocked by: 17,10 | Blocks: 21
  References: deploy-rs README (deploy.nodes + deployChecks); ORACLE P1-2.
  Acceptance: `nix eval --impure --json --expr 'builtins.getFlake "path:." | .deploy.nodes'` shows keys `["antagony","entropy","massive","remembrance"]`; `nix flake check --all-systems --no-build` passes.
  QA: eval shows `deploy.nodes.massive` + `deployChecks` present.
  Evidence: .omo/evidence/consolidate-nixos-repo/task-19-consolidate-nixos-repo.md
  Commit: Y | feat(nixos): wire deploy-rs day-2 deployment
  Recommended task executor category: deep (deploy-rs nodes + checks across 3 systems)

- [x] 20. Wire `nixos-anywhere` into the ISO flow (no-kexec) + verify the enrollment writer
  What to do / Must NOT do: Document + wire that the built ISO sets `VARIANT_ID=installer` so nixos-anywhere skips kexec; the flow is: boot ISO on Proxmox → run `nixos-anywhere --flake '.#antagony' --target-host <ip>`. Add a `docs/service-notes/nixos-anywhere-iso-install.md`. Keep the four-enrollment gate; the ISO flow writes the machine record to `model.nix` (or the flake) so enrollment has a writer (METIS B3). Do NOT write the actual `nixos-anywhere` code; only the doc + a `bin/` wrapper (optional) that shells to the `nix run` form. If a wrapper is needed, it must NOT be one of the 6 deleted names.
  References: bin/nix-config-hardware-intake (kept) accepts canonical JSON + RFC-6902 patch; `docs/service-notes/nixos-anywhere-iso-install.md` (new); METIS B3; ORACLE P1-1.
  Parallelization: Wave 5 | Blocked by: 17 | Blocks: 21
  Acceptance: doc exists; `grep -Fq 'VARIANT_ID=installer' modules/nixos/...` (if set); the `nixos-anywhere` invocation in docs uses the ISO flow; **plus (ORACLE P1-1) an enrollment-writer acceptance test: build a minimal fixture that produces a valid enrolled record (`boot.state=uefi`, `storage.profile=single-gpt-btrfs`, `publicTrust.state=enrolled`, `secretTrust.state=enrolled`) and validate it through the KEPT intake validator using its real CLI surface — `bin/nix-config-hardware-intake validate <fixture.json> <modules/entities/_machine-authority/model.nix>` (the `validate` subcommand → `apply_intake`; NOTE: intake has NO `--fixture` flag — `--fixture` lives on `nix-config-hardware-collector`/`nix-config-enroll`). It must exit 0 and produce a model.nix diff with the four enrollments set.**
  QA happy: `bash docs-gated-test` passes; the fixture gets a `model.nix` diff with the 4 enrollments.
  QA failure: intake rejects the fixture → the enrollment writer is broken (stop).
  Evidence: .omo/evidence/consolidate-nixos-repo/task-20-consolidate-nixos-repo.md
  Commit: Y | feat(nixos): ISO-first nixos-anywhere install + enrollment writer
  Recommended task executor category: unspecified-high (doc + flake wiring + enrollment writer)

- [x] 21. Final code/test gate (all-in-one)
  What to do / Must NOT do: On the MERGED + RENAMED + REMAPPED tree, run: `nix flake check --all-systems --no-build`; `bash tests/dendritic-architecture.sh`; `bash tests/dendritic-boundaries.sh`; `bash tests/dendritic-apps.sh`; `bash tests/package-policy.sh`; `nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'`; `bash tests/dendritic-shells.sh`; `python3 -m pytest tests/readiness/task15 tests/readiness/task17 scripts/hardware`; and the rename greps. Collect all results.
  Acceptance: all green; grep 0 name refs; `nix flake check --all-systems --no-build` exit 0.
  QA: see list.
  Commit: N (this is verification).
  Recommended task executor category: unspecified-high (runs the full verification battery)

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.

- [x] F1. Plan compliance audit — verify every todo completed with its evidence file; no skipped items.
- [x] F2. Code quality review — the merged nix files evaluate, no dead wiring; confirm the `codex-wrapped` shim paths + `nixPath` now use `nixos/`.
- [x] F3. Real manual QA — the agent performs a sandbox build of the ISO (if feasible) + a deploy eval; confirm no runtime path breaks.
- [x] F4. Scope fidelity — confirm the exact Must-NOT list: no future-stub hosts, no `massive` NixOS machine, no `aarch64-linux`/`nixos-x86-qualifier`, no upstream rewrites.

## Commit strategy
- Each todo with `Commit: Y` produces its own atomic, semantic commit (e.g. `feat(nixos): merge flake inputs`, `refactor(nixos): rename host`, `test(nixos): ...`).
- The merge itself is a fresh-root commit; after that, all commits are on the `main` branch of the renamed `nixos` remote.
- The 6-delete script change is a single `refactor(nixos)` commit; the ISO/deploy-rs additions are separate `feat` commits.
- Commit messages are conventional-commit style; the final wave does not commit (it's verification).
- Push to the renamed remote only at the very end, after F1–F4 approve, and only with the user's explicit go-ahead.

## Success criteria
- The merged repo `nixos/` evaluates cleanly: `nix flake check --all-systems --no-build` exit 0, all dendritic/package/boundary tests green.
- `grep -R -n --exclude-dir=.git --exclude-dir=.omo -E 'nix-config|NixOS-config|nixos-x86-qualifier|aarch64-linux' .` → 0 matches.
- Hosts named exactly: `remembrance`, `antagony`, `entropy` (NixOS/Darwin), `massive` (standalone-linux HM). No `nixos-laptop`, `nixos-x86-qualifier`, `aarch64-linux`, `aarch64-darwin` hostnames remain.
- 6 manual-ssh scripts deleted, 3 kept; `bin/` contains exactly the 3 kept + any new ISO/deploy wrappers.
- ISO-builder target exists and builds; deploy-rs nodes + checks registered.
- README + docs describe the ISO-first install; no deleted-script references remain.
- `.sops.yaml` + `.gitignore` present from B; secrets still decrypt; the codex shim paths point at `nixos/secrets/...`.
- The four-enrollment gate still has a writer (declarative model.nix per host).