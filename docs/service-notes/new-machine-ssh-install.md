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

## 0. Before anything: back up two secrets

These are **not in the repo** and a fresh clone cannot work without them:

- `~/.config/sops/age/keys.txt` (+ `recovery.txt`) — the age private keys.
  Without one, no sops secret is ever decryptable again.
- `secrets/remembrance-keys.yaml` — the local sops store holding the
  permanent-login and host private keys (gitignored by design).

Copy both to an external disk. `gen_trust.py` fails closed if either is
missing, by design.

## 1. Build the ISO

From the repo, at the commit you want to install:

```bash
nix build .#iso.<host>
```

The ISO is **not** the upstream minimal image — it is NixOS's own ISO
builder run over the host's configuration at the flake's pinned nixpkgs,
with the `hardware-enroll` oneshot and the enrollment base declaration
baked in. Flash it:

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

## 5. Run the install

```bash
bin/host-install.sh --dry-run --target-host <ip>        # preview the plan
bin/host-install.sh --target-host <ip> --skip-install   # enroll + commit only (checkpoint)
bin/host-install.sh --target-host <ip> --yes            # full run
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

- The target reboots into NixOS; the verification switch has already run.
- First console login sets `mei`'s password (bootstrap-password).
- The enrollment commit is local — push it:
  `git push origin main`.
- Day-2 updates: `nix run .#build-switch` (nh).

## If something fails

- **Enrollment artifacts missing** — the oneshot masks failures with
  `|| true`; check `journalctl -u hardware-enroll` on the target.
- **`nh: command not found`** — step 4 was skipped.
- **`gen_trust` fails** — the age key or `secrets/remembrance-keys.yaml`
  was not restored.
- **SSH auth denied** — the target's key is not yours: fix `keys` in
  `system.nix` (step 3).

## Single-machine variant

No second machine? Run steps 4–5 *inside the ISO environment* against
itself: clone the repo to `/root/nixos`, restore the backups, then
`bin/host-install.sh --target-host 127.0.0.1 --yes` (set `passwd root` on
the console first, or install your key into `/root/.ssh/authorized_keys`).
The installer runs from RAM, so wiping the disk underneath it is safe.
