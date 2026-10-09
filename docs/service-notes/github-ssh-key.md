# Authoritative GitHub SSH key

One ed25519 keypair is the GitHub identity of every machine in this repo. It is
escrowed (sops/age) in `secrets/github-ssh.yaml`, declared in
`modules/shared/files.nix` as `githubPublicKey`, and installed on every host by
home-manager activation.

    private half : escrowed in secrets/github-ssh.yaml (field github-ssh-private-key)
                   origin: ~/.ssh/id_rsa on nixos-thinkpad, the machine's own key
    public key   : ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOML7rbzZQUicy279UWUYh/7bPEr8OyUqk16kDgStJn+ mei@nixos-thinkpad-machine0
    fingerprint  : SHA256:TKsvDiX467044oODI2+jQuD7iRTLNbedH9OUfD2xVDA
    GitHub       : authentication key id 164008562, title
                   "nixos-thinkpad (fleet authoritative)", added 2026-09-21
    age form     : age1f7d77pdq406qvm9teng652sefew8f8v0qvcmayqn5zsgq2x8q3wsw65lkj

The age form is `ssh-to-age < ~/.ssh/id_github.pub`; it is recorded in
`.sops.yaml` as the `&github` recipient, and it is the identity NixOS hosts
derive from `~/.ssh/id_ed25519` (`sops.age.sshKeyPaths` in
`modules/aspects/sops.nix`), so a host can decrypt the store with the
same key it uses for GitHub.

Check the live registration with `ssh -T git@github.com`; it must answer
`Hi meillaya! You've successfully authenticated, but GitHub does not provide shell access.`

## What this key is not

`modules/nixos/system.nix` (`keys`) and `config/hosts/intake/*.json`
(`installAuthorizerPublicKey`) still pin the older entropy key
(`SHA256:MxQc4nBAjX986U2RURy/pRLXO714pBtz5odlIUuA66Q`, `mei@entropyos-nix`, GitHub
id 159544603) whose private half is not present on any machine reachable from
here. That key is the installer/root SSH trust anchor and a reviewed enrollment
artifact, so it is deliberately untouched: changing it means re-enrolling
(`bin/nix-config-hardware-intake`, `scripts/hardware/gen_trust.py`), not editing
a list.

## Where the private half lives

| Place | Path | Notes |
| --- | --- | --- |
| Escrow of record | `secrets/github-ssh.yaml` | tracked, sops/age, four recipients |
| Each host at activation | `~/.ssh/id_github` (0600) | written by `home.activation.installGithubSshKey` |
| Each host, first time only | `~/.ssh/id_ed25519` (0600) | only when that path is still free |
| Origin machine | `~/.ssh/id_rsa` on nixos-thinkpad | the key this escrow was taken from |

`modules/shared/home-manager.nix` configures `github.com` with
`IdentitiesOnly = yes` and `IdentityFile` `~/.ssh/id_github` then
`~/.ssh/id_ed25519`, so both names work. `~/.ssh/id_github.pub` stays a
home-manager file (`modules/shared/files.nix`) carrying the public half above.

## Deployment

`home.activation.installGithubSshKey` runs on `home-switch` (standalone Linux)
and `build-switch` (NixOS build, home-manager activation as the user):

1. Resolves an age identity: `$SOPS_AGE_KEY_FILE`, else
   `~/.config/sops/age/keys.txt`.
2. `sops --decrypt --extract '["github-ssh-private-key"]' --output-type binary`
   on the store that flake evaluation copied into the Nix store.
3. Validates the result with `ssh-keygen -y` before touching `~/.ssh`, then
   installs with `install -m 600`. An unchanged key is left alone (no churn), and
   an existing `~/.ssh/id_ed25519` is never overwritten; it may be a machine's
   own age identity.
4. If the identity is missing, or decryption/validation fails, it warns and
   leaves `~/.ssh` untouched. It never half-installs a file `ssh-keygen` cannot
   parse, and it never fails the switch.

Verified 2026-09-21 on the CachyOS workstation (sops 3.13.3, OpenSSH 10.5p1):

- encrypt writes all four recipients, and decryption with
  `~/.config/sops/age/keys.txt` reproduces the source key byte for byte
  (`sha256 28d644a752b1725905c329fd3c7b0276798f04d22f74847fb5ddf98d6e704bc4`,
  confirmed with `cmp`);
- decryption without a matching identity exits 128 instead of emitting a partial
  file;
- the activation body was run in a sandboxed HOME over six cases: no identity,
  valid store, re-run (no rewrite), pre-existing `id_ed25519` (preserved),
  payload rejected by `ssh-keygen`, truncated ciphertext. Every failure case
  left `~/.ssh` untouched with exit status 0.

## Requirements on a new machine

Flake evaluation only sees git-tracked files, and the store is referenced as
a path literal, so `secrets/github-ssh.yaml` must be committed for any switch to
evaluate.

An age identity must exist before the first switch that installs the key:
copy `~/.config/sops/age/keys.txt` from a machine that has one, or use the
offline `&recovery` identity. Without it the switch still succeeds and prints:

    github-ssh-key: no age identity at /home/mei/.config/sops/age/keys.txt; skipping ...

The identity must be an age key, not the SSH key: the `sops` CLI rejects an SSH
private key in `$SOPS_AGE_KEY_FILE` (verified 2026-09-21: it fails with
`Group 0: FAILED` even for a file encrypted to the matching `ssh-to-age`
recipient). Only `sops-nix` converts SSH keys itself, so the `&github` recipient
serves `sops.age.sshKeyPaths` at system activation; the home-manager activation
runs the CLI and therefore needs `keys.txt`.

## Rotation

1. Derive the new `&github` recipient (`ssh-to-age < ~/.ssh/id_github.pub`) and
   update it in `.sops.yaml`.
2. Seal the new private key over the store: `sops --encrypt --in-place
   secrets/github-ssh.yaml`, then prove the round trip:
   `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops --decrypt --extract
   '["github-ssh-private-key"]' --output-type binary secrets/github-ssh.yaml |
   cmp - <new key>`.
3. Update `githubPublicKey` in `modules/shared/files.nix`.
4. Register the new public half on GitHub (`gh ssh-key add <pub> --title ...`)
   and delete the replaced entry (`gh ssh-key delete <id>`).
5. Commit, then re-run `home-switch` / `build-switch` everywhere.
