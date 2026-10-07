# Wave 1 — lane6 (transport/recovery mechanics, completed 5m41s)

Answers with primary sources; digests only.

## 1. Mounting the old btrfs root from an installer
- Upstream ISOs: `profiles/base.nix` sets `boot.supportedFilesystems = [ "btrfs" ... ]`, which pulls
  `system.fsPackages = [ btrfs-progs ]` (modules/tasks/filesystems/btrfs.nix) and makes
  `btrfs`/`fsck.btrfs` available; kernel side `CONFIG_BTRFS_FS=m` (lead probe confirmed on the pin).
- CachyOS layout (calamares-config mount.conf + New-Cli-Installer disk.cpp): `/@`, `/@home`, `/@root`,
  `/@srv`, `/@cache`, `/@tmp`, `/@log`, `/@swap` — matches this laptop (`/proc/mounts` + fstab).
- Mount recipe: `mount -o ro,subvolid=5 <dev> /mnt/x; btrfs subvolume list /mnt/x` then
  `mount -o ro,subvol=/@home <dev> /mnt/home`. Caveat quoted from btrfs docs: the tree log IS
  replayed even on a read-only mount; use `-o ro,nologreplay` for a truly non-writing mount.
- `nixos-enter` refuses a non-NixOS tree (it hard-fails unless `etc/NIXOS` exists); for a CachyOS
  tree use `cachy-chroot` or a manual mount+chroot.

## 2. Fresh sops store creation
- The repo's `.sops.yaml` ALREADY has a rule for `secrets/remembrance-keys\.yaml$` encrypting to
  `&admin` + `&recovery` (not `&workstation`). SOPS matches `path_regex` against the path relative
  to the config file's directory (config/config.go), so a new file at that path encrypts correctly.
- Encryption needs only public recipients — **no private key**. Decryption/`sops updatekeys`/
  `sops rotate` need an identity that can unwrap the data key; `updatekeys` cannot re-encrypt a store
  you cannot decrypt (it re-encrypts the same data key). This laptop's &workstation identity is NOT
  a recipient of `remembrance-keys.yaml`, so even a freshly created store would not be decryptable
  here without `&admin`/`&recovery`.
- sops accepts SSH keys as age recipients directly and falls back to `~/.ssh/id_ed25519` for
  decryption (age/keysource.go) — this is why the repo's `sops.age.sshKeyPaths` arrangement works.
- `ssh-to-age` derives recipients (public direction) / an age identity from a private SSH key.

## 3. Staging into the target without nixos-anywhere
- `nixos-install --root` writes straight into the mounted tree (mktemp under $mountPoint, `nix-build
  --store $mountPoint`, `nix-env --store ... --set`, bootloader chroot) — the standard mechanism.
- `disko-install` and `nixos-anywhere` piggyback on exactly this; `nixos-infect`/`nixos-in-place`
  are in-place variants; `cachy-chroot` is the mount-a-subvolume-and-chroot helper.

## Resolution of the btrfs contradiction (lane6 doc claim vs lead probe)
- lane6 quoted upstream ISO modules (btrfs supported + btrfs-progs present) — true for upstream ISOs.
- Lead eval of THIS repo: `iso.antagony.passthru.config` → `btrfsProgs = false`,
  `supportedFilesystems = {iso9660,overlay,squashfs,tmpfs}` (NO btrfs/vfat);
  `iso.remembrance` (enrolled) → `btrfsProgs = true`, btrfs + vfat declared.
- Cause: the ISO is built from the host config; `antagony` is still pending, so nothing declares
  btrfs support. The kernel module still exists (`CONFIG_BTRFS_FS=m`), but the supported path needs
  a one-line addition (`boot.supportedFilesystems = [ "btrfs" "vfat" ]`, which also brings
  btrfs-progs) in the ISO extension.

## Leads
- L20: add btrfs/vfat support (+btrfs-progs) to the ISO extension for pending hosts if disk-reading
  is part of the design (owner: iso-autorun / repo-gap-map).
- L21: "reuse the sops material" premise check: a fresh store can be created without private keys,
  but the *only* identities held here are &workstation and the GitHub SSH key; the repo's store rule
  does not include them (owner: secrets-route + contrarian).
