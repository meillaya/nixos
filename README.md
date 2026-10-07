# nixos

My personal NixOS and nix-darwin config. Every machine is built from the same
Den-based aspect tree and the same machine-authority schema, so hosts stay
consistent instead of drifting apart.

## Hosts

| Host | What it is |
| --- | --- |
| `nixosConfigurations.remembrance` | NixOS workstation (this PC) |
| `nixosConfigurations.antagony` | NixOS workstation (ThinkPad P52) |
| `darwinConfigurations.entropy` | macOS workstation (Mac mini) |
| `homeConfigurations.standalone-linux` | standalone Home Manager host (`massive`, CachyOS) |

The NixOS hosts share one `mei` account (`modules/aspects/users/mei.nix`) and one
desktop stack (Niri, Noctalia, Helium/Spicetify, the Noctalia cachix setup).

## Everyday commands

```bash
nix run .#build           # dry-run the toplevel
nix run .#build-switch    # build + activate
nix run .#clean           # drop system generations older than 7 days
nix run .#update          # bump flake inputs and local source pins
nix run .#update -- nixpkgs home-manager    # or just these inputs
```

Every configured system gets the same app surface. On Linux: `build`,
`build-switch`, `clean`, `home-news`, `home-switch`, `nh`, `search-pkgs`,
`update`. On Darwin: `build`, `build-switch`, `clean`, `search-pkgs`, `update`.

`nh` is the day-2 tool: it builds, shows the activation diff, and switches.

```bash
nix run .#nh -- os switch
nix run .#nh -- os switch --hostname remembrance
nix run .#nh -- home switch --hostname standalone-linux
nix run .#nh -- os dry-build      # see the diff before touching the system
```

`build-switch` and `apps/<system>/build-switch` shell out to `nh os switch`, so
you get that diff review either way.

## Install

Three ways in, all behind the same trust rules: the one-command app on the
target, the operator script from another machine, and the opt-in autostart on
the installer ISO.

### One command on the target

Boot the machine into a live Linux with Nix (this repo's own ISO is the
recommended one) and run:

```bash
sudo nix run --extra-experimental-features 'nix-command flakes' \
  github:meillaya/nixos#install -- --yes
```

It detects known laptop models (a ThinkPad P52 maps to `antagony`; pass
`--host <name>` otherwise), copies the flake into a writable work tree
(`/root/nixos-install`), and probes the real hardware through the same reviewed
intake pipeline the ISO oneshot uses: CPU and microcode, UEFI/boot, the internal
disk binding, GPU, network controllers, firmware, power, suspend. It commits the
enrollment into the work tree, folds the fresh host key into the sops store when
it can, then hands the build gate and the destructive install to
`bin/host-install.sh --install-only` (which re-checks `--yes` itself).

Just before that call it mints a one-time password for `mei` and stages it,
along with the enrollment artifacts and the age identity, into the installed
system. The password is printed once for the first login and never written to
disk.

Without `--yes` the run stops at the enrollment checkpoint, so you can review
the probed declaration first:

```bash
sudo nix run .#install --                  # probe + enroll, print the summary
sudo nix run .#install -- --yes            # build gate + install + reboot
sudo nix run .#install -- --dry-run        # print the plan, execute nothing
sudo nix run .#install -- --skip-fold --save /mnt/usb/enroll --yes
```

`--skip-fold` keeps the host key local instead of folding it into
`secrets/remembrance-keys.yaml`. The enrollment artifacts are staged into the
installed system either way, and `--save DIR` keeps an extra copy on persistent
storage.

If the age identity only exists on the disk being wiped, pass
`--rescue-identity`: the app mounts the live btrfs layout read-only, copies
`~/.config/sops/age/keys.txt` into the stage, and refuses to continue if it
cannot find it. On a headless box, the GPU renderer digest falls back to the
selected GPU's PCI identity.

The install stage refuses to run unless `/` is a live tmpfs or overlay root,
which means you booted the ISO. Erasing the enrolled disk from a disk-backed
root would take out the system under the installer. `--allow-mounted-root`
bypasses that check when the target disk is genuinely not the running root.

The upstream NixOS minimal ISO works too, with the flakes flag and the same
secret caveats. It has no `hardware-enroll` oneshot and no baked-in base
declaration, so only this one-command path works on it. The operator flow below
needs the per-host ISO. See
[`docs/service-notes/nixos-anywhere-iso-install.md`](docs/service-notes/nixos-anywhere-iso-install.md).

### From the operator side

`bin/host-install.sh` wraps the ISO-driven install. Run it from a machine that
holds this repo, with the target booted into the installer ISO:

```bash
bin/host-install.sh --target-host <ip> --yes
```

Three things stay manual. Build the per-host ISO:

```bash
nix build .#iso.<host>
```

`.#iso.<host>` is shorthand for
`.#nixosConfigurations.<host>.config.system.build.images.iso`, and the artifact
lands in `result/iso/`. Where it lives in the store, how to smoke-test it in
QEMU, and how to put it on a stick:
[`docs/service-notes/iso-build-and-qemu-test.md`](docs/service-notes/iso-build-and-qemu-test.md).
Then boot the target from it (a Proxmox VM works fine), and know the target's
IP. The script does not build the ISO, boot the target, or guess the address.

With `--target-host <ip> --yes` it runs the whole flow in order:

1. Generate the canonical `trust.json` from repo facts.
2. Upload it and trigger the ISO's `hardware-enroll` oneshot.
3. Pull the enrollment artifacts back from `/root/enroll/`.
4. Commit them: the intake config into `config/hosts/intake/`, the re-encrypted
   sops host key into `secrets/`.
5. Run a pre-flight `nh os build` gate on the refreshed flake.
6. Mint a per-install password for `mei` into a tmpfs stage, add the enrollment
   artifacts, and with `--stage-identity SRC` the age identity. Print the
   password once, forward the stage as `nixos-anywhere --extra-files`.
7. Install via `nixos-anywhere` (partition plus first activation).
8. Verify with `nh os switch`.

The tool roles are fixed: `nixos-anywhere` installs, `nh` is the pre-flight
build gate and the day-2 switch tool. `nh` never installs.

Modes:

```bash
bin/host-install.sh --target-host <ip> --skip-install        # enroll + commit only, no install
bin/host-install.sh --target-host <ip> --dry-run             # print the command plan, execute nothing
bin/host-install.sh --target-host <ip> --yes --skip-verify   # skip the post-install nh switch
bin/host-install.sh --target-host <ip> --install-only        # build gate + install, skip enroll/fold
bin/host-install.sh --target-host <ip> --yes --skip-fold     # keep the host key local
bin/host-install.sh --target-host <ip> --yes --extra-files <dir>   # overlay extra files on the target
bin/host-install.sh --target-host <ip> --yes --chown home/mei/.config 1000:100  # repeatable
bin/host-install.sh --target-host <ip> --yes --stage-identity ~/.config/sops/age/keys.txt
```

`--host` defaults to `remembrance`; pass `--host <host>` for other NixOS hosts.
The install itself is gated behind `--yes`. On this path (anything except
`--install-only`) the script mints and stages the password itself.
`--extra-files` and repeatable `--chown <path> <owner>` go straight through to
`nixos-anywhere`, and `--stage-identity SRC` is off by default so your own age
key is never staged implicitly.

### Opt-in autostart at boot

A plain boot of the installer ISO stays inert: it probes nothing and never
touches a disk. To let a booted ISO install by itself, edit the boot entry at
the boot menu and append:

```
nixos.autoinstall=1
```

That flag is a per-boot decision and never lands in `boot.kernelParams`, so
nothing can start an install on its own.

With the flag set, `nixos-autoinstall.service` runs the flake's install app for
the ISO's host as `--yes --rescue-identity`, once the network and the enrollment
oneshot are up. It still has to pass the same gates as a manual run, including
the host and disk match. If it fails, `iso-install-rescue.target` drops to a
root shell on tty1 for triage instead of rebooting in a loop.

The ISO config, the gate, and the inert default boot are pinned by the ISO eval
wall and by a VM check that boots the config with and without the flag.

### The trust gate

The four-enrollment gate is the boundary for any physical install:

| Field | Enrolled value |
| --- | --- |
| `boot.state` | `uefi` |
| `storage.profile` | `single-gpt-btrfs` |
| `publicTrust.state` | `enrolled` |
| `secretTrust.state` | `enrolled` |

Git history records who enrolled what. Before installing on a new machine, back
up the two secrets a fresh clone cannot recreate, as described in
[`docs/service-notes/new-machine-ssh-install.md`](docs/service-notes/new-machine-ssh-install.md).
That note is the step-by-step walkthrough, including the single-machine variant;
the manual procedure the script wraps is in
`docs/service-notes/nixos-anywhere-iso-install.md`.

## Containers

Docker and Podman are rootless-only on every host this repo manages
(`modules/aspects/features/rootless-containers.nix`):

- NixOS hosts run `virtualisation.docker.rootless` (a per-user dockerd that
  exports `DOCKER_HOST`) and podman with its rootless user socket. The rootful
  docker daemon, podman's system socket, and the root-equivalent `docker` group
  are all off. The user manager lingers, so both sockets work without an
  interactive login.
- The standalone Linux home (a foreign distro with Nix) gets the rootless podman
  user socket plus a docker-compatible `DOCKER_HOST`, so docker clients never
  need a root daemon there either.
- Darwin is left alone: Docker Desktop/colima and `podman machine` already run
  the engine inside a VM, not as a host root process.

## Tooling flakes

Beyond the default Den and flake-parts inputs, `flake.nix` registers four
extras:

- **`stylix`** (`github:danth/stylix`) for declarative system-wide theming. The
  aspect lives in `modules/aspects/features/stylix.nix` and is gated behind
  `stylix.enable = false` until you pick a palette and font per host in
  `stylix.targets.<host>.colors` / `.fonts`.
- **`nix-direnv`** (`github:nix-community/nix-direnv`). The aspect in
  `modules/aspects/features/nix-direnv.nix` imports
  `inputs.nix-direnv.nixosModules.default` and enables `programs.nix-direnv` on
  every NixOS host. It pairs with the `use flake` line in `.envrc`.
- **`nh`** (`github:viperML/nh`, currently 4.4.2), a drop-in replacement for
  `nixos-rebuild` and `home-manager` with diff review and `flake.lock`
  awareness. Exposed as a flake app; see [Everyday commands](#everyday-commands).
- **`preservation`** (`github:nix-community/preservation`). The aspect in
  `modules/aspects/features/preservation.nix` (wired in from
  `modules/aspects/platforms/linux.nix`) keeps `/etc/machine-id`, `/etc/ssh`,
  `/var/lib`, `/var/db`, `/var/log`, `/srv`, `/home` and `/root` from churning
  across rebuilds via bind mounts. NixOS only: it is skipped on Darwin.

## Secrets

Only the GitHub SSH key is managed as a repository secret. Home Manager
activation installs the encrypted keypair for the `mei` user; it has nothing to
do with agent tooling.

## Layout

```
flake.nix                     repo entry point (flake-parts + Den)
flake.lock                    locked inputs
lib/nixpkgs.nix               unfree allowlist policy
modules/
  entities/                   hosts + machine authority
  aspects/
    features/                 leaf capability aspects (niri, noctalia, ...)
    platforms/                OS-level chains (linux.nix)
    roles/                    workstation
    hardware/                 vendor + capability routing
    storage/                  storage policy (disko wiring)
    named-hosts/              hostname + identity projection
    hosts/                    host aggregates
    users/mei.nix             user + Home Manager projection
    shared-policy/nixpkgs.nix nixpkgs config overlay
  flake/                      flake-parts wiring (dendritic, checks, packages, apps)
  nixos/                      NixOS implementation modules
  shared/                     cross-platform package and file surfaces
  linux/                      NixOS Linux desktop surface (also used by standalone-linux)
pkgs/                         repo-local derivations
secrets/                      sops-encrypted secrets
tests/                        architecture, config-eval, package-policy, readiness
scripts/                      hardware intake + readiness tasks
config/                       intake and install-sandbox schemas
docs/                         service notes + machine audits
```

The Darwin tree (`modules/darwin/`) and the standalone Linux tree
(`modules/standalone-linux/`) both live here. `modules/shared/`,
`modules/linux/`, the `mei` user aspect, the `noctalia` and `sops` aspects, and
`modules/standalone-linux/config/noctalia/config.toml` are used by both.

## Verification

Run these before applying anything:

```bash
nix flake check --all-systems --no-build
bash tests/dendritic-architecture.sh
bash tests/dendritic-boundaries.sh
bash tests/dendritic-apps.sh
bash tests/package-policy.sh
nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}'
```

Disk layout and the first-install password have their own destructive-risk tests
under `tests/bootstrap-password-*`. Run them after touching NixOS aspects or the
install docs.
