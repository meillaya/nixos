# Installing NixOS on a new machine over SSH

The whole install is one command from any machine holding this repo:

```bash
bin/host-install.sh --target-host <ip> --yes
```

This note is the practical walkthrough: what to prepare, what to run, and
the handful of things that are easy to miss. The trust boundary (four
enrollments, reviewed machine record) is unchanged — see
[`nixos-anywhere-iso-install.md`](./nixos-anywhere-iso-install.md) for the
manual procedure this wraps.

## The short path: one command on the target itself

When no second machine is available, the flake app does the whole flow on the
target. Boot a live Linux environment with Nix (the flake's own ISO is the
recommended one), then:

```bash
sudo nix run --extra-experimental-features 'nix-command flakes' \
  github:meillaya/nixos#install -- --yes
```

The app detects the machine (a ThinkPad P52 maps to `antagony`; otherwise pass
`--host <name>`), copies the flake into a writable work tree, probes the real
hardware through the same intake pipeline the ISO oneshot uses, commits the
enrollment, folds the fresh host key into the sops store when the two secrets
below are present, then runs the build gate and `nixos-anywhere` against
`root@127.0.0.1`. Without `--yes` it stops after the enrollment checkpoint;
`--dry-run` prints the plan. When the sops store or age identity is missing,
`--skip-fold --save <persistent-dir>` keeps the enrollment recoverable instead.
The install stage refuses to start unless `/` is a live tmpfs/overlay root, so
the RAM-resident ISO is the supported environment.

The upstream NixOS minimal ISO works for this path too (with the flakes flag
and the same secret caveats); see
[`nixos-anywhere-iso-install.md`](./nixos-anywhere-iso-install.md#using-the-official-nixos-minimal-iso).
It cannot drive the operator-side flow, which needs the `hardware-enroll`
oneshot baked into the per-host ISO.

The rest of this note is the operator-side variant, which needs an SSH-reachable
target and a second machine holding the repo.

## 0. Before anything: back up two secrets

These are **not in the repo** and a fresh clone cannot work without them:

- `~/.config/sops/age/keys.txt` (+ `recovery.txt`) — the age private keys.
  Without one, no sops secret is ever decryptable again.
- `secrets/remembrance-keys.yaml` — the local sops store holding the
  permanent-login and host private keys (gitignored by design).

Copy both to an external disk. The operator flow fails closed without them:
`gen_trust.py` needs the sops store to verify an enrolled host's
permanent-login key, and the fold stage needs it to re-encrypt the host key.
(The one-command app can still enroll a *new* host without them, because
`gen_trust.py` falls back to the fleet record's operator facts; it then
requires `--skip-fold --save` instead of the fold.)

The authoritative GitHub SSH key is **no longer** in that list: it is escrowed
in the tracked store `secrets/github-ssh.yaml` and installed at `~/.ssh/id_github`
by home-manager activation on the first `home-switch`/`build-switch` — provided
the new machine has an age identity (see
[`github-ssh-key.md`](./github-ssh-key.md)).

## 1. Build the ISO

From the repo, at the commit you want to install:

```bash
nix build .#iso.<host>
```

The per-host ISO is **not** the upstream minimal image — it is NixOS's own ISO
builder run over the host's configuration at the flake's pinned nixpkgs, with
the `hardware-enroll` oneshot and the enrollment base declaration baked in,
plus `VARIANT_ID=installer` so `nixos-anywhere` skips kexec. Flash it:

```bash
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## 2. Boot the target

- Boot from the USB (UEFI). The installer runs from RAM; the disk is
  untouched until the install stage.
- Bring the network up (ethernet, or `nmcli` for Wi-Fi) and get the
  address: `ip a`.

## 3. SSH access to the installer

The ISO enables sshd. Root accepts the key listed in
`modules/nixos/system.nix` (`keys`) — that must be **your** key, since it
is also the SSH trust anchor of the installed system and of the
post-install verification step.

```bash
ssh root@<ip> true && echo reachable
```

If it fails: fix `keys` in `system.nix`, rebuild the ISO, or set a root
password on the target console (`passwd root`) and let the script's
ssh/scp prompt you.

## 4. Prepare the operator machine

On the machine holding the repo (a second machine, or the target itself —
see the single-machine note below):

```bash
git clone https://github.com/meillaya/nixos && cd nixos
# restore the two backups from step 0:
#   age keys   -> ~/.config/sops/age/keys.txt
#   sops store -> secrets/remembrance-keys.yaml
git config user.email you@example.com && git config user.name you
nix profile install github:viperML/nh --profile /nix/var/nix/profiles/default
```

`nh` is not in `systemPackages`, and the pre-install build gate needs it.
The git identity is needed because the fold stage commits the enrollment.
The flake app (`nix run github:meillaya/nixos#install`) ships `nh` itself, so
this step only applies to the operator-side flow.

## 5. Run the install

```bash
bin/host-install.sh --dry-run --target-host <ip>        # preview the plan
bin/host-install.sh --target-host <ip> --skip-install   # enroll + commit only (checkpoint)
bin/host-install.sh --target-host <ip> --yes            # full run
bin/host-install.sh --target-host <ip> --install-only   # build gate + install, skip enroll/fold
bin/host-install.sh --target-host <ip> --yes --skip-fold    # keep the host key out of the sops store
```

With `--yes`, the stages run in order — enroll (upload trust fixture,
trigger `hardware-enroll`, pull the artifacts back), fold (commit the
refreshed enrollment + re-encrypted host key), `nh os build` gate, then
`nixos-anywhere` partitions the target disk and installs, and after the
reboot `nh os switch` verifies the deployed system over SSH.

Disk selection is automatic on the target: the already-bound disk is
preferred when present, otherwise the largest internal disk (USB devices
are excluded).

## 6. After the install

- The target reboots into NixOS; the verification switch has already run in the
  operator flow. The one-command app cannot verify after the reboot (it runs on
  the target), so it skips that stage; day-2 `nh os switch` takes over.
- First console login sets `mei`'s password (bootstrap-password).
- The enrollment commit is local — push it: `git push origin main`. In the app
  flow the commit lives in the RAM work tree (`/root/nixos-install`), so copy it
  out first with `--save DIR` (or run the app from a persistent `--workdir` and
  commit/push from there) before the machine reboots.
- Day-2 updates: `nix run .#build-switch` (nh).

## If something fails

- **Enrollment artifacts missing** — the oneshot masks failures with
  `|| true`; check `journalctl -u hardware-enroll` on the target.
- **`nh: command not found`** — step 4 was skipped.
- **`gen_trust` fails** — the age key or `secrets/remembrance-keys.yaml`
  was not restored, and (for a re-run) the host record diverges from the
  fleet record's operator facts.
- **SSH auth denied** — the target's key is not yours: fix `keys` in
  `system.nix` (step 3).
- **The app refuses with "`/` is a `btrfs` filesystem"** — the install stage
  only runs from a live environment so the enrolled disk can be erased safely;
  boot the ISO (or pass `--allow-mounted-root` when the target disk is not the
  running root).
- **The app demands `--save`** — `--skip-fold` keeps the host key out of the
  sops store, so the enrollment must be written somewhere persistent first.

## Single-machine variant

No second machine? Use the flake app: `nix run github:meillaya/nixos#install`
inside the ISO environment does exactly this variant — it copies the repo to a
work tree, sets up root SSH to itself, probes the hardware, enrolls, and runs
the build gate plus `nixos-anywhere` against `127.0.0.1`.

The manual equivalent is steps 4–5 *inside the ISO environment*: clone the repo
to `/root/nixos`, restore the backups, then
`bin/host-install.sh --target-host 127.0.0.1 --yes --skip-verify` (set
`passwd root` on the console first, or install your key into
`/root/.ssh/authorized_keys`; `--skip-verify` is required because the reboot
replaces the installer environment running the script). The installer runs from
RAM, so wiping the disk underneath it is safe.
