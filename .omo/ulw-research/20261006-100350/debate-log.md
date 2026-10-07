# Debate log (one row per debate round)

| round | claim under attack | attacker's argument | defender's evidence | verdict | changed in the claim graph |
|---|---|---|---|---|---|
| D1 | C7 (extra-files preserves 0600/root:root) | docs say "after installation"; `--no-same-owner` says nothing about modes; extraction must be root for same-permissions | source L876-885 (tar before nixos-install) + upstream test + lead tar experiment (VA1) | STANDS for 0600/0700; 0700/setuid scoped to VA1 | C7 -> partial/supported, scope note added |
| D2 | C8 (ISO can read the old btrfs disk) | "btrfs-progs present" is false on iso.antagony; module presence != loaded | lead eval (supportedFilesystems empty, btrfsProgs false) + CONFIG_BTRFS_FS=m + kmod present | WEAK -> fixed by design additions | C8 -> partial with an explicit one-line fix |
| D3 | Silent wipe (the autostart gate) | the cmdline flag alone cannot authorize a wipe; wrong machine, typo, GRUB, reboot-loop failure modes | disko `_legacyDestroy` has no prompt; the app's --yes + live-root are the only gates | STANDS, with the trigger-not-authorization rule adopted | gate design gained the disk/host match + completion marker |
| D4 | C2 (password) | `!` sentinel safety under mutableUsers; the staging leg is a recovered script with no e2e run | update-users-groups.pl semantics + lifecycle tests + VA4 (executed) | STANDS for the contract; WEAK for e2e (honestly labeled) | C2 -> supported/contract, residual e2e note |
| D5 | Framing: custom installer | category error (the flake ISO already is one); only autostart is marginal and untested | iso-images.nix + community consensus + lane1 coverage finding | NO new installer | I6 closed; M6 verdict rewritten |
| D6 | Framing: reuse the sops store | nothing consumes the store; the real irreversible item is the &workstation identity | lane14 greps + secrets-route executed runs | REFRAMED | I3 rewritten; M3 replaced by identity preservation |
