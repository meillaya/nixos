# Wave 1 — member prior-art (Axis E) — interim report received

## Recipes and their verdicts

1. `live.nixos.passwd=<pw>` (installation-cd-base.nix postBootCommands): sets the LIVE installer's
   `nixos` user password from the kernel cmdline. Plaintext on cmdline; live env only. Crib as an
   additive operator convenience, not as the installed-system mechanism.
2. nixos-anywhere phase/flag surface — same verdict as axis B.
3. Clan: phase -> destination secret mapping (`activation,users,services` -> --extra-files;
   `partitioning` -> --disk-encryption-keys per file) then phase loop. Crib the idea.
4. Boot-target + `OnFailure=multi-user.target` rescue shape (disc 39748) — crib the safety fallback;
   grub.cfg patching is brittle.
5. disko-install + offline closure baking; PR #1223 (offline unattended images module) UNMERGED
   (checked 2026-10-06).
6. nixos-facter report via `--generate-hardware-config`; keep the repo validator as trust gate.
7. **activationScript /mnt injection** (disc 52168#2): `system.activationScripts.<x>.text` copies a
   path from the ISO store into the installed system at first activation — works on the OFFICIAL ISO
   too, but the source path lands in the world-readable nix store of the ISO.
8. Bossearch: minimal install flake -> post-reboot full config; reject sshpass/plaintext.
9. tfc: trampoline install with literal root password in the store (its README flags the leak).
10. misuzu: getty-target dropin install; UEFI-only.
11. snabblab (2019): oneshot install + `initialPassword` plaintext in store — historical proof of the
    shape; do not copy the auth.
12. Xe (2022): oneshot sfdisk+mkfs+nixos-install.
13. NiklasGollenstede: partlabel-based disk association; read-only crib.
14. **Community consensus (disc 33244)**: ElvishJerricco/nrdxp/uep/TLATER — a custom ISO is not
    needed to install a custom system; nixos-install is idempotent and sops ciphertext rides in the
    closure. Directly answers I6's framing.
15. Non-NixOS analogues: Ubuntu autoinstall/cloud-init, Debian preseed, Kickstart, AutoYaST,
    archinstall --config — all "declare up front, installer runs, reboots".

## Anti-patterns (do not crib)
plaintext passwords in the store; sshpass+plaintext; hardcoded shared root passwords; Ventoy;
baking LUKS keys as build inputs; patching ISO grub.cfg; depending on nixos-generators (deprecated /
upstreamed to `nixos-rebuild build-image`); depending on disko PR #1223.

## Claims (member)

- `live.nixos.passwd=` is upstream and sets only the live installer's `nixos` user (normal risk).
- A custom installer ISO is unnecessary for installing a custom system (community consensus;
  counter: airgapped installs do need a baked image) — supports the I6 verdict.
- nixos-anywhere has no true local mode (already triple-confirmed).
- disko PR #1223 unmerged as of 2026-10-06 (high risk if relied on).

## Lead's fs sweep (this turn)

Searched /home, /var/lib, /var/backups, /mnt, /media, /run/media, /srv, /opt, /tmp for yaml/json
files mentioning `remembrance`/`sops_version`/`age1`: the only sops-encrypted artifacts on this laptop
are the repo's `secrets/github-ssh.yaml` and `backups/tidewater.jsonlz4` (both admin+recovery-ish
recipients; the backup README documents restoring it). `remembrance-keys.yaml` remains absent.
Open question for the user: which store did they mean ("one exists on this laptop")? The design
handles both cases: with a store path -> fold/use; without -> create fresh material encrypted to
identities they hold.
