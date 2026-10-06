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

### One command on the target (no operator machine)

Run the installer on the machine being installed, booted into a live Linux
environment with Nix (the flake's own ISO is the recommended one):

```bash
sudo nix run --extra-experimental-features 'nix-command flakes' \
  github:meillaya/nixos#install -- --yes
```

The command auto-detects a known laptop model (a ThinkPad P52 maps to
`antagony`; pass `--host <name>` otherwise), copies the flake into a writable
work tree (`/root/nixos-install`), probes the real hardware through the same
reviewed intake pipeline the ISO oneshot uses — CPU/microcode, UEFI/boot,
the internal disk binding, GPU, network controllers, firmware, power and
suspend — commits the enrollment into the work tree, folds the freshly
generated host key into the sops store when it is available, and then hands
the build gate and the destructive `nixos-anywhere` install to
`bin/host-install.sh --install-only` (which re-checks `--yes` itself). Just
before that destructive call it mints a one-time password for `mei` and stages
it, together with the enrollment artifacts and the age identity, into the
installed system; it prints the password once for the first login and never
writes it to disk.

The upstream NixOS minimal ISO works here too (keep the flakes flag and the
secret caveats). It has no `hardware-enroll` oneshot and no baked-in base
declaration, so only this one-command app path works on it; the operator flow
below needs the per-host ISO. See
[`docs/service-notes/nixos-anywhere-iso-install.md`](docs/service-notes/nixos-anywhere-iso-install.md).

Without `--yes` the run stops after the enrollment checkpoint so the probed
declaration can be reviewed first:

```bash
sudo nix run .#install --                  # probe + enroll, print the summary
sudo nix run .#install -- --yes            # build gate + install + reboot
sudo nix run .#install -- --dry-run        # print the plan, execute nothing
sudo nix run .#install -- --skip-fold --save /mnt/usb/enroll --yes
```

`--skip-fold` keeps the host key local instead of folding it into
`secrets/remembrance-keys.yaml`; the enrollment artifacts are staged into the
installed system regardless, and `--save DIR` keeps an extra copy on persistent
storage. When the age identity exists only on the disk being wiped, pass
`--rescue-identity`: the app mounts the live btrfs layout read-only, copies
`~/.config/sops/age/keys.txt` into the stage, and refuses to continue when it
cannot find the identity. Without a display, the GPU
renderer digest falls back to the selected GPU's PCI identity so headless
live environments can still enroll. The install stage itself is refused unless
`/` is a live tmpfs/overlay root (boot the ISO): erasing the enrolled disk from
a disk-backed root would destroy the running system underneath the process.
`--allow-mounted-root` bypasses that check for the rare case where the target
disk is not the running root.

### From the operator side

Installation is ISO-driven and wrapped by one operator-side command,
`bin/host-install.sh`. Run it from a machine holding this repo, against
the target booted into the installer ISO:

```bash
bin/host-install.sh --target-host <ip> --yes
```

Three prerequisites stay human. Build the per-host installer ISO:

```bash
nix build .#iso.<host>
```

(`.#iso.<host>` is shorthand for
`.#nixosConfigurations.<host>.config.system.build.images.iso`; the artifact
lands in `result/iso/`.) Write it
to a USB stick and boot the target from it (e.g. a Proxmox VM). Then
know the target's IP. The script does not build the ISO, boot the
target, or guess the address.

With `--target-host <ip> --yes`, the script runs the whole flow in
order:

1. Generates the canonical `trust.json` from repo facts.
2. Uploads it to the target and triggers the ISO's `hardware-enroll`
   oneshot.
3. Retrieves the enrollment artifacts from `/root/enroll/`.
4. Commits them: the intake config into `config/hosts/intake/` and the
   re-encrypted sops host key into `secrets/`.
5. Runs a pre-flight `nh os build` gate on the refreshed flake.
6. Mints a per-install password for `mei` into a tmpfs stage, adds the
   enrollment artifacts, and with `--stage-identity SRC` the age identity,
   then prints the password once and forwards the stage as
   `nixos-anywhere --extra-files`.
7. Installs via `nixos-anywhere` (partition + first activation).
8. Verifies post-install with `nh os switch`.

Tool roles are fixed: `nixos-anywhere` is the installer; `nh` is the
pre-flight build gate and the day-2 switch tool. `nh` never installs.

Modes:

```bash
bin/host-install.sh --target-host <ip> --skip-install   # enroll + commit only, no install
bin/host-install.sh --target-host <ip> --dry-run        # print the exact command plan, execute nothing
bin/host-install.sh --target-host <ip> --yes --skip-verify  # skip the post-install nh switch
bin/host-install.sh --target-host <ip> --install-only   # build gate + install, skip enroll/fold
bin/host-install.sh --target-host <ip> --yes --skip-fold    # keep the host key local
bin/host-install.sh --target-host <ip> --yes --extra-files <dir>   # overlay extra files into the target
bin/host-install.sh --target-host <ip> --yes --chown home/mei/.config 1000:100  # repeatable
bin/host-install.sh --target-host <ip> --yes --stage-identity ~/.config/sops/age/keys.txt
```

`--host` defaults to `remembrance`; pass `--host <host>` for the other
NixOS hosts. The install path is gated behind `--yes`. On this operator path
(not `--install-only`) the script mints and stages the password itself;
`--extra-files` and repeatable `--chown <path> <owner>` are forwarded straight
to `nixos-anywhere`, and `--stage-identity SRC` is off by default so the
operator's own age key is never staged implicitly.

### Auto-install at boot (opt in)

The installer ISO stays inert on a plain boot: it probes nothing and never
touches a disk. To let a booted ISO install by itself, append
`nixos.autoinstall=1` to the kernel command line at the boot menu (edit the
boot entry, add the flag, boot it). The flag is a per-boot decision and is
never placed in `boot.kernelParams`, so no automatic path can start an install.

With the flag present, `nixos-autoinstall.service` runs the flake's own install
app for the ISO's host with `--yes --rescue-identity`, after the network and the
enrollment oneshot are up. It still has to pass the same trust gates as a manual
run, including the host and disk match. A failure activates
`iso-install-rescue.target`, which drops to a root shell on tty1 for triage
instead of rebooting into a loop. The ISO config, the gate, and the inert
default boot are covered by the ISO eval wall and a VM check that boots the
config both with and without the flag.

The four-enrollment gate (`boot.state=uefi`,
`storage.profile=single-gpt-btrfs`, `publicTrust.state=enrolled`,
`secretTrust.state=enrolled`) is the trust boundary. Git history records
who enrolled what.

For the step-by-step walkthrough on a new machine — including the secret
backups a fresh clone needs and the single-machine variant — see
[`docs/service-notes/new-machine-ssh-install.md`](docs/service-notes/new-machine-ssh-install.md).
The full manual procedure the script wraps is in
`docs/service-notes/nixos-anywhere-iso-install.md`.

## Containers

Docker and Podman are rootless-only on every host this repo manages
(`modules/aspects/features/rootless-containers.nix`):

- NixOS hosts run `virtualisation.docker.rootless` (a per-user dockerd that
exports `DOCKER_HOST`) and podman with its rootless user socket; the rootful
docker daemon, podman's system socket, and the root-equivalent `docker` group
are all off, and the user manager lingers so both sockets are reachable
without an interactive login.
- The standalone Linux home (a foreign distro with Nix) gets the rootless
podman user socket plus a docker-compatible `DOCKER_HOST`, so docker clients
never need a root daemon there either.
- Darwin is untouched: Docker Desktop/colima and `podman machine` already run
the engine inside a VM, never as a host root process.

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

Only the GitHub SSH key is managed as a repository secret. The encrypted
keypair is installed by the `mei` Home Manager activation and is unrelated to
agent tooling.

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
