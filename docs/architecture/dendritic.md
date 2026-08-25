# Dendritic configuration architecture

This repository uses [Den](https://github.com/denful/den) as its entity and
aspect layer and flake-parts as its only outer output composer. Den is pinned to
an audited revision in `flake.nix`; review Den's migration notes and rerun all
cross-platform evaluations before changing that pin.

## Composition boundaries

`flake.nix` intentionally contains only inputs and one `mkFlake` call.
`import-tree` loads the flake modules under `modules/flake/`:

- `dendritic.nix` loads Den plus the entity/aspect trees.
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

`modules/entities/hosts.nix` is the inventory. It declares:

- `remembrance` and `antagony` (`x86_64-linux`) NixOS machines;
- the `entropy` (`aarch64-darwin`) macOS machine;
- the `standalone-linux` (x86_64-linux) Home Manager output; and
- the `mei` user on each managed host.

Intel Darwin is retired; `x86_64-darwin` is neither an evaluation system nor a
configuration output.
`configurationEvaluationPaths` names outputs that CI evaluates; it does not
classify them as production releases.

Entity declarations contain only explicit system, machine, identity, hostname,
and membership data. Strict Den schemas declare every repository extension to
host, user, home, aspect, and flake entities. Host and home machine attachments
structurally type identity, target, system, role, boot, storage, capabilities,
and remote-install authority before aspect projection. `machine-authority.nix`
exposes the closed, validated authority used by the inventory. Put behavior in
an aspect, never in the registry. The public x86 output name remains
architecture-oriented for compatibility, while its literal machine identity is
`nixos-laptop`. The standalone home carries explicit machine, username, and home
directory data and never consults evaluator environment variables.

## Aspects and ownership

Machine composition follows one acyclic, inward-only chain:

```text
shared policy -> OS platform -> role -> hardware profile
              -> storage profile -> named host
```

- `shared-policy` owns common Nixpkgs config and overlays.
- `linux-platform` and `darwin-platform` select only their OS-specific baseline,
  secrets, and Home Manager integration.
- Role aspects add workstation, qualifier, or evaluation session policy.
- Hardware aspects select one role and project `host.machine`, the authority
  attached to the active Den entity. They never re-import a literal global
  machine ID, so projection cannot drift from the selected entity.
- A disabled device or capability enrollment means that no enrollment-specific
  option projection is added. It does **not** globally force baseline services
  off; upstream feature modules retain ownership of their baseline defaults.
- Storage aspects select one hardware profile and assert the current `none`
  profile; they add no Disko or destructive storage behavior.
- Literal named-host aspects own hostname, location, and OS account projection.
  The compatibility `x86_64-linux` aspect selects `nixos-laptop`; all other
  entities select their same-named host aspect directly.

The generic `nixos-workstation` and `darwin-workstation` aspects remain aliases
for callers, not entity-selected aggregates. `standalone-linux` remains a
separate Home Manager aggregate combining the shared `mei` home with current
upstream Noctalia behavior.

Leaf aspects under `modules/aspects/features/` own one coherent capability.
The `mei` aspect under `modules/aspects/users/` owns cross-platform user and
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

Linux machine declarations currently have disabled boot/storage authority. CI
and operators may build their toplevels without activating them:

```bash
cd ~/nixos
git pull --ff-only
nix run .#build
```

The Linux app inventory derives activation authority from the machine records.
`build-switch` builds the selected toplevel and runs `sudo nixos-rebuild
switch`; `clean` deletes system generations older than 7 days. Standalone
`home-switch` and `home-news` remain available on both Linux systems.

The Apple Silicon machine exposes the same `build-switch`, `clean`, `update`,
`build`, and `search-pkgs` apps, where `build-switch` runs
`sudo darwin-rebuild switch`; native Darwin build, activation, rollback, and
TCC checks remain **NOT VERIFIED** until the first real switch. Credential
scripts accept only the typed identity supplied by an authorized wrapper, never
ambient `$USER`.

Log out and back in after changing the graphical session configuration. Niri is
the only generated login session. Verify Noctalia with:

```bash
systemctl --user status noctalia.service --no-pager
journalctl --user -u noctalia.service -b --no-pager
```

## Adding configuration

1. Add a leaf aspect when the behavior is a reusable capability.
2. Select it through platform, role, hardware, storage, and named-host layers.
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
