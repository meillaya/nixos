# Wave 1 — lane4 (NixOS/sops-nix docs) — completed

Pins: nixpkgs nixos-25.05 ac62194c3917d5f474c1a844b6fd6da2db95077d; sops-nix dcd241ba;
ssh-to-age 886b718.

## Password options (users-groups.nix)

- Precedence with `mutableUsers = true`: initialHashedPassword -> initialPassword -> hashedPassword ->
  password -> **hashedPasswordFile wins**. With `mutableUsers = false`: hashedPasswordFile is LAST
  (initialHashedPassword wins).
- `initialPassword`/`initialHashedPassword` are create-only under mutable users; `initialPassword` puts
  PLAINTEXT in the nix store.
- `hashedPasswordFile` is re-read on every activation; must be exactly one `chpasswd -e`-suitable line.
- `update-users-groups.pl` when the file is missing: warns, **does not fall back** (the `elsif` skips
  `password`), and a brand-new account gets `"!"` (locked). With mutableUsers=true an existing account
  keeps its shadow hash; with false it is force-rewritten.
- `initialPassword` hashing uses `$6$` (SHA-512 crypt) — its own default only.

## nixos-install / nixos-enter

- Flags: --root (default /mnt), --system/--closure, --flake (fragment enforced), --channel,
  --no-channel-copy, **both --no-root-password and --no-root-passwd**.
- The root-password prompt is conditional on stdin being a TTY AND `passwd` existing in the target.
- nixos-enter re-execs in a private mount namespace, refuses a tree without `etc/NIXOS`, runs the
  target's activate + systemd-tmpfiles, then chroots (default bash --login).

## sops-nix runtime (sops-install-secrets/main.go)

- Key sources: gpg home, gpg ssh keys, age.keyFile, age.sshKeyPaths; an assertion requires at least
  one configured source.
- `age.generateKey` (default false) runs `age-keygen` only if the file is absent — a fresh RANDOM key.
- **A missing/unreadable `age.keyFile` is FATAL** ("cannot read keyfile"); an unreadable/unconvertible
  SSH key is a NON-fatal warning (loop continues).
- sops-install-secrets writes `age-keys.txt` and exports SOPS_AGE_KEY_FILE.
- For `users.users.<n>.hashedPasswordFile` fed from sops, the secret needs `neededForUsers = true`
  (lands in /run/secrets-for-users before user creation).

## Yescrypt acceptance (three independent sources)

1. rl-2211 release note: crypt is libxcrypt; the documented flow is `mkpasswd` + yescrypt hash.
2. nixpkgs libxcrypt `enableHashes = "strong"`, `enabledCryptSchemeIds` starts with "y" (yescrypt);
   shadow builds `--with-yescrypt` with libxcrypt.
3. PAM's default password stack sets `yescrypt = true` on pam_unix.so.
=> A `$y$` hash from `mkpasswd --method=yescrypt` is accepted at login.

## Leads

- L25: systemd-sysusers/userborn path changes the password-option semantics entirely (the repo
  asserts sysusers/userborn are DISABLED in bootstrap-password.nix, so this is a guard to keep).
- L26: sops `neededForUsers` matters if the design ever sources the password hash from sops.
