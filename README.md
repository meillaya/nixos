# nixos

One flake for four machines: two NixOS workstations (`remembrance`, `antagony`),
one macOS host (`entropy`), and one standalone Linux Home Manager host
(`standalone-linux`). Every host comes from the same Den aspect tree and the
same machine-authority schema, so a capability is declared once and inherited
where it belongs.

## Quickstart

```bash
nix run .#build                # dry-run the toplevel build
nix run .#build-switch         # build and activate this host
nix run .#nh -- os dry-build   # print the activation diff, change nothing
```

`nh` is the day-2 tool: it builds, shows the diff, and switches, and it never
installs. `nix run .#update` bumps the flake inputs. `nix run .#clean` drops
system generations older than seven days.

## Install a machine

Build the per-host installer ISO, boot the target from it, then run one command
on the target:

```bash
nix build .#iso.<host>
sudo nix run --extra-experimental-features 'nix-command flakes' \
  github:meillaya/nixos#install -- --yes
```

Without `--yes` the run stops after the enrollment checkpoint, so you can read
the probed machine declaration before anything is written. The install is gated
on a reviewed enrollment and refuses to erase the disk it runs from. The full
procedure, the trust gate, and the operator-side variant are in the notes below.

## Documentation

- [docs/architecture/dendritic.md](docs/architecture/dendritic.md): composition, ownership, shell policy, desktop policy.
- [docs/architecture/inputs.md](docs/architecture/inputs.md): the extra flake inputs and what each enables.
- [docs/service-notes/nixos-anywhere-iso-install.md](docs/service-notes/nixos-anywhere-iso-install.md): the install flow and the four-enrollment gate.
- [docs/service-notes/new-machine-ssh-install.md](docs/service-notes/new-machine-ssh-install.md): the operator-side walkthrough.
- [docs/service-notes/iso-build-and-qemu-test.md](docs/service-notes/iso-build-and-qemu-test.md): build the ISO, test it in QEMU, write a stick.
- [docs/service-notes/rootless-containers.md](docs/service-notes/rootless-containers.md): the container policy.
- [docs/service-notes/zix.md](docs/service-notes/zix.md) and [tools/zix/README.md](tools/zix/README.md): packages, version pins, sandboxes, VMs.
- [secrets/README.md](secrets/README.md): the sops store and its recipients.
- [agent-settings.nix](agent-settings.nix): the rules agents follow in this repo.

## Checks

```bash
nix flake check --all-systems --no-build
```

`zix check` runs the same suite. The `tests/bootstrap-password-*`
scripts bind-mount `/var/lib` and `/etc/shadow`, so run them only for an install
or a password change.
