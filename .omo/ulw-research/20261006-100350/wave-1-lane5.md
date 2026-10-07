# Wave 1 — lane5 (prior-art catalog, completed)

Full catalog in the transcript; this digest keeps the decisive recipes, all SHA/URL-pinned in the return.

## Recipes worth cribbing (ranked by the lane)

1. **nixos-anywhere phase/flag surface** (`--phases`, `--no-reboot`, `--copy-host-keys`,
   `--extra-files`, `--disk-encryption-keys`, `--generate-hardware-config nixos-facter`,
   `--disko-mode mount`, `--build-on`): the repo already depends on this tool; exposing them is a thin
   `bin/host-install.sh` change. Lowest risk, highest payoff (resumable installs, repair mode, LUKS).
2. **nixos-facter report format** as the probe's serialization, keeping `_machine-authority` as the
   trust gate (`hardware.facter.reportPath` is the documented nixpkgs module). Crib format, not trust.
3. **`live.nixos.passwd=`** (installation-cd-base.nix `boot.postBootCommands`) = upstream-sanctioned
   kernel-cmdline root password for the INSTALLER (plaintext, RAM only). Additive to the ISO.
   Plus Clan installer knobs: `system.installer.channel.enable = false`, zswap kernel params.
4. **Clan's phase-stratified secret upload**: `activation_secrets -> --extra-files`,
   per-file `partitioning_secrets -> --disk-encryption-keys`, phases looped
   kexec->disko->install->reboot (clan-core @ 557b482: clanServices/installer/README.md,
   pkgs/clan-cli/clan_lib/machines/install.py). The right generalization of the repo's host-key fold.
5. **Offline/airgap core**: bake `config.system.build.diskoScript` + closureInfo store-paths into the
   image, then `disko-install --flake ... --disk ...` or
   `nixos-install --no-channel-copy --no-root-password --system <toplevel>` + `reboot`
   (disko docs @ 725ea35; discourse 50618 post 2; nixpkgs make-disk-image @ 151fa4e).
6. **Boot-menu systemd target** (discourse 39748 post 3, accepted): `unattended-install.target` +
   `systemd.unit=` kernel cmdline, `SuccessAction = "reboot"`, `OnFailure = "multi-user.target"`
   to drop to a rescue shell. Direct ancestor of the repo's oneshot; the grub.cfg patching is
   described as brittle.
7. **Bossearch gist** (minimal install-flake -> first-boot `nixos-rebuild boot`; inject host key into
   `/mnt/etc/ssh`; LUKS key via `luksAddKey`). Adopt the /mnt injection idea; REJECT sshpass +
   plaintext password.nix + whole-repo git add.
8. **Avoid**: nixos-generators (deprecated in favor of `system.build.images`), tfc/nixos-auto-installer
   (hardcoded shared root password; its README admits the store leak), misuzu's recipe (UEFI-only base).
   disko PR #1223 (offline unattended images module) is still open - watch, don't depend.

## Coverage gaps reported by the lane

- Reddit r/NixOS: both search-JSON endpoints returned anti-bot shells; NO reddit primary evidence
  (so the other browsing lane's reddit angle is the only chance - and it may be blocked too).
- clan.lol docs are JS-only; quoted clan-core repo source at a pinned SHA instead.
- `nixos-install --no-root-passwd` cited from make-disk-image.nix + the manual, not source-verified.

## Leads

- L12: expose the nixos-anywhere phase/flag surface + the boot-menu target pattern in the ISO design
  (owner: iso-autorun member).
- L13: nixos-facter's schema vs the repo's typed probe (owner: anywhere-flags / lead).
- L14: airgap closure-baking is a possible future path; not required for the ThinkPad (network exists).
