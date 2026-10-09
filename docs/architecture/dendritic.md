# Dendritic configuration architecture

This repository uses [Den](https://github.com/denful/den) as its entity and
aspect layer and flake-parts as its only outer output composer. Den is pinned to
an audited revision in `flake.nix`; review Den's migration notes and rerun all
cross-platform evaluations before changing that pin.

## Repository layout

```text
flake.nix                     repo entry point (flake-parts + Den)
flake.lock                    locked inputs
lib/nixpkgs.nix               unfree allowlist policy
modules/
  aspects/                    ONE flat directory: every aspect, the registry, the schema
    inventory.nix             den.hosts / den.homes - the single entity registry
    schema.nix                lib.types schemas + Den schema extensions
    authority.nix             publishes flake.machineAuthority
    _machine-authority/       model.nix, validators.nix, crypto.nix (private)
    nixpkgs.nix               nixpkgs config + overlays (shared-policy)
    linux.nix, darwin.nix     OS baseline chains
    workstation-*.nix         role aggregators
    remembrance.nix, ...      one file per host
    storage-<host>.nix        per-host boot/storage branch
    <capability>.nix          leaf capability aspects (niri, noctalia, ...)
    mei.nix                   user + Home Manager projection
  flake/                      flake-parts wiring (dendritic, checks, packages, apps)
  nixos/                      NixOS implementation modules
  darwin/                     nix-darwin implementation modules
  shared/                     cross-platform package and file surfaces
  linux/                      Linux desktop surface (NixOS and standalone-linux)
  standalone-linux/           the standalone Home Manager home
pkgs/                         repo-local derivations
secrets/                      sops-encrypted secrets
tests/                        architecture, config-eval, package-policy, readiness
scripts/                      hardware intake + readiness tasks
config/                       intake and install-sandbox schemas
docs/                         architecture, service notes, machine audits
tools/zix/                    the zix CLI
```

`modules/aspects/` is deliberately flat. Which composition layer a file belongs to
is carried by its name rather than its folder, so `ls modules/aspects/` is the whole
index and finding a host never means choosing between six candidate folders. The
trade is that the shared/private distinction is a naming convention rather than a
directory boundary; `tests/dendritic-architecture.sh` pins the flat shape and the
`host.machine` rule that keeps every aspect bound to its own entity.

The Darwin tree (`modules/darwin/`) and the standalone Linux tree
(`modules/standalone-linux/`) both live here. `modules/shared/`,
`modules/linux/`, the `mei` user aspect, the `noctalia` and `sops` aspects, and
`modules/standalone-linux/config/noctalia/config.toml` are used by both.

## Composition boundaries

`flake.nix` intentionally contains only inputs and one `mkFlake` call.
`import-tree` loads the flake modules under `modules/flake/`:

- `dendritic.nix` loads Den plus the flat aspect tree (`import-tree ../aspects`).
  The raw implementation trees (`nixos/`, `darwin/`, `shared/`, `linux/`,
  `standalone-linux/`) sit outside that root and are reached only by an explicit
  relative `import`, so a payload module can never be auto-loaded as a flake module.
- `systems.nix` declares the two supported evaluation systems.
- `packages.nix`, `apps.nix`, and `dev-shells.nix` own normal flake-parts
  `perSystem` outputs.
- `outputs.nix` exposes the six configuration evaluation paths without mixing
  package output construction into machine configuration. This inventory is an
  evaluation contract, not a production-release or activation declaration.

Den exclusively creates `nixosConfigurations`, `darwinConfigurations`, and
`homeConfigurations`. Do not reintroduce `nixosSystem`, `darwinSystem`, or
`homeManagerConfiguration` calls in `flake.nix`.

## Entities

`modules/aspects/inventory.nix` is the inventory. It declares:

- `remembrance` and `antagony` (`x86_64-linux`) NixOS machines;
- the `entropy` (`aarch64-darwin`) macOS machine;
- the `massive` (x86_64-linux) Home Manager output, plus a `systemConfigs.massive`
  system layer that owns the hostname and the tailscaled service; and
- the `mei` user on each managed host.

Intel Darwin is retired; `x86_64-darwin` is neither an evaluation system nor a
configuration output.
`configurationEvaluationPaths` names outputs that CI evaluates; it does not
classify them as production releases.

Entity declarations contain only explicit system, machine, identity, hostname,
and membership data. Strict Den schemas declare every repository extension to
host, user, home, aspect, and flake entities. Host and home machine attachments
structurally type identity, target, system, role, boot, storage, capabilities,
and remote-install authority before aspect projection. `authority.nix`
exposes the closed, validated authority used by the inventory. Put behavior in
an aspect, never in the registry. Each host's literal machine identity is its own
hostname (`remembrance`, `antagony`, `entropy`), validated by
`_machine-authority/validators.nix`. The standalone home carries explicit machine, username, and home
directory data and never consults evaluator environment variables.

## Aspects and ownership

Machine composition follows one acyclic, inward-only chain:

```text
shared policy -> OS platform -> role -> hardware profile
              -> storage profile -> named host
```

- `nixpkgs.nix` (`shared-policy`) owns common Nixpkgs config and overlays.
- `linux.nix` and `darwin.nix` select only their OS-specific baseline,
  secrets, and Home Manager integration.
- Role aspects (`workstation-linux.nix`, `workstation-darwin.nix`) add
  workstation session policy.
- The boot/storage branch (`storage-<host>.nix`, `enrolled-x86*.nix`,
  `pending-x86-workstation.nix`) selects one hardware profile and asserts the
  current `none` profile; it adds no Disko or destructive storage behavior.
- `<host>.nix` owns hostname, location, and OS account projection, asserting the
  machine target/system/role before `mkForce`ing them from `host.machine`.

Every host-attached aspect projects `host.machine`, the authority attached to
the active Den entity. None re-imports a literal global machine ID, so projection
cannot drift from the selected entity; `tests/dendritic-architecture.sh` enforces
that no aspect imports `_machine-authority` and calls `authority.getMachine`.

Den selects an entity's aspect by the entity's own name (`lookupAspect`), so the
aspects keyed on a system or a generic role name (`x86_64-linux`,
`nixos-workstation`, `darwin-workstation`, `massive-aarch64`,
`qualifier-role-linux`, `evaluation-role-linux`) were never reachable and have
been removed. `massive` remains a Home Manager aggregate combining the shared
`mei` home with upstream Noctalia behaviour, and it is the one host whose system
level comes from `system-manager` rather than NixOS or nix-darwin.

A disabled device or capability enrollment means that no enrollment-specific
option projection is added. It does not globally force baseline services off;
upstream feature modules retain ownership of their baseline defaults.

Leaf aspects (`modules/aspects/<capability>.nix`, e.g. `niri.nix`, `sops.nix`) own
one coherent capability. A capability only one host needs may live inline in that
host's file instead, so the tree never grows a shared file for a single consumer.
The `mei` aspect (`modules/aspects/mei.nix`) owns cross-platform user and
Home Manager behavior. Home Manager content must remain on a user aspect or be
delivered explicitly with `provides.to-users` for a genuinely host-selected
payload. A host-class module must not request Den's `user` argument; current Den
silently suppresses that route.

The `mei` aspect includes Den's `define-user` and `primary-user` batteries, so
account names, home directories, normal/admin membership, NetworkManager access,
and Darwin's primary user all originate from the user entity rather than being
redeclared in OS modules.

## Shell policy

Nushell is configured explicitly rather than through
`den.batteries.user-shell`, because NixOS and nix-darwin do not expose a matching
OS-level `programs.nushell` option.

- NixOS and Darwin register Nushell, Bash, Zsh, and Fish as valid shells.
- `users.users.mei.shell` points to the pinned Nushell package.
- Home Manager enables all four shells.
- Ghostty, Konsole, and standalone Kitty profiles use the absolute Nix-store Nu path with
  `--login`.
- tmux inherits the account shell.
- OMX's internal wrapper deliberately keeps its Zsh/Bash compatibility path;
  interpreter-specific scripts and `/bin/sh` shebangs are not rewritten.

## Linux desktop policy

Niri is the default display-manager session on NixOS. One cross-class
`den.aspects.noctalia` concern imports Noctalia's upstream NixOS module for
NixOS hosts and its upstream Home Manager module for standalone Linux homes.
Both modules start exactly one Noctalia systemd user service wanted by
`graphical-session.target`; do not add a second `spawn-at-startup "noctalia"`
entry to the shared Niri configuration.

The upstream Home Manager module generates and validates the standalone TOML at
build time. Its service uses Home Manager's `X-SwitchMethod=keep-old` extension,
so `sd-switch` does not stop or restart the live shell during activation. The
upstream NixOS module does not expose settings/config-file ownership, so the
NixOS Home Manager file entry remains the single owner of that host's TOML.
Noctalia launches applications as separate systemd services so launcher children
do not remain trapped in the shell service's cgroup. Operational details are in
`docs/service-notes/niri-noctalia-session.md`.

The cross-host evaluation test keeps the primary graphical application set in
sync between NixOS and standalone Linux. Add generally useful Linux desktop apps
to both package surfaces, or intentionally document why a package is host-only.

Enrolled hosts (remembrance) carry full boot/storage authority; a pending host
(antagony) gets its enrollment written by the one-command installer before the
destructive stage. CI and operators may build any declared toplevel without
activating it:

```bash
cd ~/nixos
git pull --ff-only
nix run .#build
```

The Linux app inventory derives activation authority from the machine records.
`install` runs the reviewed enrollment and the first install on a live target;
`build-switch` builds the selected toplevel and activates it via `nh os switch`;
`clean` deletes system generations older than 7 days. Standalone `home-switch`
and `home-news` remain available on both Linux systems.

The Apple Silicon machine exposes the same `build-switch`, `clean`, `update`,
`build`, and `search-pkgs` apps, where `build-switch` runs
`sudo darwin-rebuild switch`; native Darwin build, activation, rollback, and
TCC checks remain not verified until the first real switch. Credential
scripts accept only the typed identity supplied by an authorized wrapper, never
ambient `$USER`.

Log out and back in after changing the graphical session configuration. Niri is
the only generated login session. Verify Noctalia with:

```bash
systemctl --user status noctalia.service --no-pager
journalctl --user -u noctalia.service -b --no-pager
```

## Adding configuration

1. Add a leaf aspect (`modules/aspects/<name>.nix`) when the behavior is a reusable
   capability.
2. Select it through the platform, role, storage, and host layers.
3. Attach only identity/data to an entity; aspect selection is name-driven.
4. Put cross-platform personal programs/files on `den.aspects.mei.homeManager`.
5. Keep packages/apps/dev shells in flake-parts, not Den entities.
6. Avoid recursive legacy imports, string-based profile selectors, lateral
   reads of unrelated configuration, and hidden `specialArgs` plumbing.

Before applying a change, run:

```bash
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-apps.sh
nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'
bash tests/dendritic-shells.sh
nix flake check --all-systems --no-build
```

Disk and first-install password behavior has separate destructive-risk tests;
run every `tests/bootstrap-password-*` script after changing NixOS aspects or
installation documentation.
