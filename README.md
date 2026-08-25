# nixos

Personal NixOS configuration: workstation hosts on NixOS and macOS.
Each host shares the same Den-based aspect architecture as
`~/nixos/` and lives behind the same machine authority schema.

## Hosts

- `nixosConfigurations.remembrance` — NixOS workstation (this PC).
- `nixosConfigurations.antagony` — NixOS workstation (ThinkPad P52).
- `darwinConfigurations.entropy` — macOS workstation (Mac mini).
- `homeConfigurations.standalone-linux` — standalone Linux Home-Manager host (massive, CachyOS).

The NixOS hosts share the same `mei` user account via
`modules/aspects/users/mei.nix` and the same NixOS desktop feature stack
(Niri, Noctalia, Helium/Spicetify, Noctalia Cachix setup).

## Build, switch, clean

```bash
nix run .#build              # dry-run toplevel build
nix run .#build-switch       # build + sudo nixos-rebuild switch (defaults to x86_64-linux)
nix run .#clean              # delete system generations older than 7 days
```

All configured systems get the flake app surface: on Linux `build`,
`build-switch`, `clean`, `home-news`, `home-switch`, `nh`, `search-pkgs`,
`update`; on Darwin `build`, `build-switch`, `clean`, `search-pkgs`,
`update`.

## Install

Installation is ISO-driven. Build a per-host installer ISO, boot it on
the target, then run `nixos-anywhere` to install the flake.

```bash
nix build .#iso.<host>
```

(`.#iso.<host>` is shorthand for
`.#nixosConfigurations.<host>.config.system.build.isoImage`.) Boot the
ISO on the target (e.g. a Proxmox VM), then run nixos-anywhere:

```bash
nix run github:nix-community/nixos-anywhere -- --flake '.#<host>' --target-host <ip>
```

nixos-anywhere auto-detects the installer and skips kexec. The
four-enrollment gate (`boot.state=uefi`,
`storage.profile=single-gpt-btrfs`, `publicTrust.state=enrolled`,
`secretTrust.state=enrolled`) is the trust boundary. Git history records
who enrolled what.

See `docs/service-notes/nixos-anywhere-iso-install.md` for the full
procedure.

## Update

```bash
nix run .#update               # flake inputs + local source pins
nix run .#update -- nixpkgs home-manager
```

## Tooling flakes

The flake registers four extras beyond the default Den + flake-parts
inputs (see `flake.nix`):

- **`stylix`** — declarative system-wide theming
  (`github:danth/stylix`). Aspect wired into
  `modules/aspects/features/stylix.nix`, gated by
  `stylix.enable = false` until you pick a palette + font in
  `stylix.targets.<host>.colors` / `.fonts` per host.
- **`nix-direnv`** — `github:nix-community/nix-direnv`. Aspect in
  `modules/aspects/features/nix-direnv.nix` imports
  `inputs.nix-direnv.nixosModules.default` and enables
  `programs.nix-direnv` on every NixOS host. The `use flake` line in
  `.envrc` pairs with this.
- **`nh`** — `github:viperML/nh` (viperML/nh 4.4.2). Drop-in
  replacement for `nixos-rebuild` / `home-manager` with built-in diff
  review and `flake.lock` awareness. Exposed as a flake app:

  ```bash
  nix run .#nh -- os switch                  # build + activate on this host
  nix run .#nh -- os switch --hostname remembrance
  nix run .#nh -- home switch --hostname standalone-linux
  nix run .#nh -- os dry-build              # see the activation diff
  ```

  `build-switch` and `apps/<system>/build-switch` now delegate to
  `nh os switch` internally, so `nix run .#build-switch` picks up the
  same diff-review flow.

- **`preservation`** — `github:nix-community/preservation`. Aspect in
  `modules/aspects/features/preservation.nix` (wired into
  `modules/aspects/platforms/linux.nix`). Preserves `/etc/machine-id`,
  `/etc/ssh`, `/var/lib`, `/var/db`, `/var/log`, `/srv`, `/home`,
  `/root` against rebuild churn via bind mounts. NixOS-only — skipped
  on the Darwin side because `preservation` is NixOS-flavored.

## Secrets

Only `sops-nix` is wired. The five coding-agent API keys
(`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`,
`OPENROUTER_API_KEY`, `GITHUB_TOKEN`) are evaluated from
`secrets/coding-agents.yaml` for both Linux hosts via the
`den.aspects.sops` chain. The recipient policy is `.sops.yaml` at the
repo root.

## Coding agents

`codex` and `omo-ai@beta` are installed by the standalone Home Manager
activation block — the wrappers, install hooks, and other agents
(`kimi`, `hermes`, `zeroclaw`, `pi`, `opencode`, `omo-agent-toolkit`)
are removed. `lazycodex` is installed manually via
`npx lazycodex-ai install`. The shared `codex-wrapped` shim injects
provider keys from the sops file at runtime.

## Layout

```
flake.nix                     repo entry point (flake-parts + Den)
flake.lock                    locked inputs
lib/nixpkgs.nix               unfree-allowlist policy
modules/
  entities/                   host + machine authority
  aspects/
    features/                 leaf capability aspects (niri, noctalia, etc.)
    platforms/                OS-level chains (linux.nix)
    roles/                    workstation
    hardware/                 vendor + capability routing
    storage/                  storage policy (Disko wiring)
    named-hosts/              hostname + identity projection
    hosts/                    host aggregates
    users/mei.nix             user + Home Manager projection
    shared-policy/nixpkgs.nix nixpkgs config overlay
  flake/                      flake-parts wiring (dendritic, checks, packages, apps, etc.)
  nixos/                      NixOS implementation modules
  shared/                     cross-platform package + file surfaces
  linux/                      NixOS Linux desktop surface (also used by standalone-linux)
pkgs/                         repo-local derivations
secrets/                       sops-encrypted secrets
tests/                        architecture + config-eval + package-policy + readiness tests
scripts/                      hardware intake + readiness tasks
config/                       hardware intake + install sandbox schemas
docs/                         service notes + machine audits
```

The Darwin (`modules/darwin/`) and standalone Linux
(`modules/standalone-linux/`) trees live in this single repo. Shared
modules (`modules/shared/`, `modules/linux/`, the `mei` user aspect,
the `noctalia` and `sops` aspects, and
`modules/standalone-linux/config/noctalia/config.toml`) are used by
both trees from this one repo.

## Verification

```bash
nix flake check --all-systems --no-build
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-apps.sh
nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'
bash tests/package-policy.sh
```

Disk and first-install password behaviour have separate destructive-risk
tests under `tests/bootstrap-password-*`; run every one of them after
changing NixOS aspects or installation documentation.
