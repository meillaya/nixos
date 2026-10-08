# PROJECT KNOWLEDGE BASE

**Generated:** 2026-09-25T01:53:22Z
**Commit:** 0e80408
**Branch:** main

## OVERVIEW
Personal Nix flake for one Den dendritic configuration tree: two NixOS workstations,
one Apple Silicon macOS workstation, and one standalone Linux Home Manager host, all
sharing the same `mei` user aspect and machine-authority schema.

## STRUCTURE
```
nixos/
├── flake.nix            # inputs only + one mkFlake call; import-tree ./modules
├── modules/
│   ├── entities/        # the inventory: den.hosts / den.homes, machine authority
│   ├── aspects/         # the only place behavior lives (platforms/roles/hardware/storage/named-hosts/users/features)
│   ├── flake/           # flake-parts outputs per system
│   ├── nixos/           # low-level NixOS + HM modules owned by aspects
│   ├── shared/          # cross-platform HM payload for the mei user
│   ├── linux/           # Linux HM payload shared by NixOS and standalone-linux
│   ├── darwin/          # nix-darwin modules
│   └── standalone-linux/# the standalone HM home
├── apps/<system>/       # committed app scripts (build, build-switch, clean)
├── tests/               # architecture + boundaries + config-eval + policy + readiness
├── bin/                 # operator entry points (install, enrollment, cachix)
├── scripts/hardware/    # the enrollment/intake pipeline behind bin/
├── pkgs/                # repo-local derivations
├── tools/zix/           # zix: standalone CLI (own flake); every host installs it
├── zix.json             # zix manifest: package targets, tools, switches
├── zix/managed/         # zix-generated package set + version pins (manifest is canonical)
├── config/              # intake declarations + install/package schemas
├── secrets/             # sops/age stores (see secrets/README.md)
└── docs/                # architecture + service notes + dated audits
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add or change a host | `modules/entities/hosts.nix` + a named-host aspect | identity/data in the entity, behavior in the aspect |
| Add a capability | `modules/aspects/features/<name>.nix` | then select it through the chain below |
| Change the composed chain | `modules/aspects/{platforms,roles,hardware,storage}/` | inward-only, one direction |
| Add / remove / pin a package | `zix add ...` (long form `zix pkg add`; `nix run .#zix` also works) | tools/zix/README.md; curated lists still live in `modules/*/packages.nix` |
| Sandbox or VM work | `zix sandbox\|vm ...` | omnibin image / rewindvm passthrough |
| Change zix behaviour | `zix.json` | targets, tools, switches, checks |
| Allow an unfree package | `config/package-exceptions.json` | time-boxed 90-day entry; consumed by `lib/nixpkgs.nix` |
| Flake outputs / apps | `modules/flake/` + `apps/<system>/` | flake-parts `perSystem`, never Den entities |
| Install a new machine | `bin/host-install.sh`, `docs/service-notes/new-machine-ssh-install.md` | gated behind `--yes` |
| Run the checks | `tests/` | see COMMANDS |

## CODE MAP
| Symbol | Type | Location | Refs | Role |
|--------|------|----------|------|------|
| `den.hosts` / `den.homes` | entity inventory | `modules/entities/hosts.nix` | Den | the only host/home registry |
| `getMachine` / `assertValid` | Nix function | `modules/entities/_machine-authority/{model,validators}.nix` | 4 | the closed machine-authority record |
| `mkPkgs` / `config` | Nix attrset | `lib/nixpkgs.nix` | 7 | nixpkgs policy, unfree allowlist, emacs overlay |
| `den.aspects.mei` | aspect | `modules/aspects/users/mei.nix` | Den | user + cross-platform HM payload |
| `den.schema.*` | schema extension | `modules/entities/defaults.nix` | Den strict | typed host/user/home/aspect/flake extensions |
| `configurationEvaluationPaths` | flake option | `modules/flake/outputs.nix` | 1 test | evaluation inventory, not release authority |
| `flake.iso.<host>` | flake output | `modules/flake/iso-images.nix` | install | per-host installer ISO carrying `hardware-enroll` |
| `main` | Python entry | `scripts/hardware/cli.py` | 2 wrappers | `collect` / `create` / `validate` hardware intake |

## CONVENTIONS
- `flake.nix` holds inputs and ONE `mkFlake` call. Den exclusively creates
  `nixosConfigurations`, `darwinConfigurations`, `homeConfigurations`.
- Machine composition is one acyclic, inward-only chain:
  `shared-policy -> {linux,darwin}-platform -> role -> hardware -> storage -> named host`.
- Put behavior in an aspect, never in the registry. Entities carry only explicit
  system/machine/identity/hostname/membership data.
- Aspect file shape: `{ den, ... }: { den.aspects.<name> = ...; }`. Reference peers as
  `den.aspects.<peer>`, select by name, never by string.
- `zix` owns package-list edits: entries live between `# BEGIN zix` / `# END zix`
  markers or in the generated `zix/managed/` set, with
  `zix/managed/manifest.json` as the single source of truth. The CLI is its own
  flake under `tools/zix/` and every host installs that derivation, so `zix add`
  works from any directory; `nix run .#zix` remains the checkout path.
- Repo-local packages go through `pkgs.callPackage` from an existing package list.
- `secrets/*` is ignored except the three tracked files; the untracked ones are by design.
- `.gitattributes` marks every non-`.nix` path non-linguist-detectable, so GitHub
  counts this repo as pure Nix.
- Agent rules for code, tests, commit messages, and prose live in
  `agent-settings.nix`. `tools/check-prose.py` enforces the mechanical half of
  the prose rules; `tests/prose.sh` and the `prose` flake check run it.

## ANTI-PATTERNS (THIS PROJECT)
- No `nixosSystem` / `darwinSystem` / `homeManagerConfiguration` calls in `flake.nix`. Den owns them.
- No `specialArgs` / `extraSpecialArgs` anywhere in `flake.nix`, `modules/flake`, `modules/entities`, `modules/aspects`.
- No `runCommand` / `mkDerivation` in production modules (`lib/`, `modules/*` except `modules/flake/{apps,checks}.nix`).
- No recursive import of `modules/nixos` and no host construction there.
- No hardcoded `"mei"` / `/home/mei` / `/Users/mei` in active modules - read `host.machine.identity`.
- No `builtins.getEnv` in `modules/nixos/files.nix`; the standalone home never consults evaluator env.
- A host-class module must not request Den's `user` argument (Den silently suppresses that route).
- No `den.batteries.user-shell "nushell"`; Nushell is configured explicitly.
- Never hand-edit `zix/managed/*` or the inside of a `# BEGIN zix` block: both are
  generated - use `zix add` / `zix rm` so the manifest and the files stay in sync.
- No second Niri session authority: Noctalia alone owns bar, notifications, lock, wallpaper.
- No `spawn-at-startup "noctalia"` in the Niri config.
- The retired desktop stack must not come back: polybar, dunst, rofi, waybar, mako, picom,
  bspwm, sxhkd, waybar, swaybg, awww/swww, i3lock, betterlockscreen.
- Never hand-edit `config/hosts/intake/*.json` (pipeline output) or `secrets/remembrance-keys.yaml`
  (use `bin/nix-config-host-key-enroll`).
- Committed enrollment records are not authorization to erase a machine.

## UNIQUE STYLES
- Machine identity is typed data, not prose: role/boot/storage/capabilities/remoteInstall
  are validated before any aspect projects them.
- Capability enrollment is all-or-nothing per device: disabled means no projection is
  added, and baseline services keep their upstream defaults.
- Aliases `nixos-workstation` / `darwin-workstation` exist for callers; real hosts select
  a literal named-host aspect.
- Sops: encryption needs no identity, decryption does (`$SOPS_AGE_KEY_FILE`, else
  `~/.config/sops/age/keys.txt`). The `&github` recipient is derived from the GitHub SSH key.
- Intake JSON is canonical (sorted keys, no trailing whitespace) and digest-bound; the
  system is written in Nushell.

## COMMANDS
```bash
nix run .#build                # dry-run toplevel build
nix run .#build-switch         # build + activate (delegates to nh os switch)
nix run .#home-switch          # standalone Linux Home Manager switch (default target standalone-linux)
nix run .#update               # flake inputs + local source pins
nix run .#clean                # delete system generations older than 7 days
zix doctor                     # zix: packages, pins, sandboxes, VMs; on PATH
zix --help                     # after a switch (tools/zix/README.md)
nix build .#iso.<host>         # per-host installer ISO (install prerequisite
                               # unless the installer URI is given explicitly)

# checks (cheap, run all before applying)
nix flake check --all-systems --no-build
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-apps.sh
bash tests/dendritic-shells.sh
bash tests/package-policy.sh
nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'
```

## NOTES
- `nix flake check` also runs the dendritic `.sh` checks, `zix`, and package-policy as
  `perSystem` derivations, so a single flake check covers the same invariants with a
  longer compile.
- `tests/bootstrap-password-*.sh` are destructive-risk (they bind-mount `/var/lib`,
  `/etc/shadow`); run them deliberately, never as a reflex after unrelated edits.
- Linux machine declarations currently hold disabled boot/storage authority, so the
  toplevels build and evaluate without activation authority. `nh` is the pre-flight
  build gate and the day-2 switch tool; it never installs.
- Files that must be git-tracked to evaluate: `secrets/github-ssh.yaml` is referenced as
  a path literal, and flake evaluation only sees tracked files.
- Four host codenames exist: `remembrance` and `antagony` (NixOS), `entropy` (macOS) and
  `standalone-linux`, deployed as home-manager under hostname `massive` (`modules/flake/deploy-rs.nix`).
- Only `remembrance` is enrolled; its record is the committed intake artifact. `antagony` and
  `entropy` carry inline pending records with boot/storage/capabilities disabled.
- Unfree pins in `config/package-exceptions.json` are version-exact; on nixpkgs drift the first
  refused package aborts output evaluation (`nix flake check` fails on the darwin toplevel first).
  `scripts/check-unfree-pins.py` lists every drifted pin; refresh version fields only.
- The flake builds only `x86_64-linux` and `aarch64-darwin`; Intel Darwin is retired.
