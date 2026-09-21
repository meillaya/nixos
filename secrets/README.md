Place local sops-encrypted secret files in this directory when needed.

This directory is intentionally ignored by git (except for the tracked files
listed below) so the public flake can bootstrap on fresh Linux installs without
fetching a private GitHub secrets repository during evaluation.

Tracked, committed, sops/age-encrypted:

- `coding-agents.yaml` — agent API keys (`OPENAI_API_KEY`,
  `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY`, `GITHUB_TOKEN`),
  declared as `sops.secrets.*` in `modules/aspects/features/sops.nix`.
- `github-ssh.yaml` — the authoritative GitHub SSH keypair, field
  `github-ssh-private-key`. Installed on every host at `~/.ssh/id_github` (and at
  `~/.ssh/id_ed25519` when that path is still free) by
  `home.activation.installGithubSshKey` in `modules/aspects/users/mei.nix`. See
  [../docs/service-notes/github-ssh-key.md](../docs/service-notes/github-ssh-key.md).

Untracked by design, never commit:

- `remembrance-keys.yaml` — per-host private keys produced by enrollment.
  `scripts/hardware/gen_trust.py` reads it and fails closed when it is missing.

Recipients live in `../.sops.yaml`: `&admin` and `&recovery` (standalone age
identities), `&workstation` (`~/.config/sops/age/keys.txt` on the CachyOS
workstation) and `&github` (the age identity derived from the authoritative
GitHub key with `ssh-to-age`, which is what NixOS hosts get from
`sops.age.sshKeyPaths = ~/.ssh/id_ed25519`).

Decrypting requires an age identity on the machine: `$SOPS_AGE_KEY_FILE`, else
`~/.config/sops/age/keys.txt`. Encryption needs no identity at all — the
recipients in `.sops.yaml` are public — so a fresh clone can add secrets but not
read them.

For per-tool runtime API keys (OpenAI, Anthropic, etc.), use the
`codex-wrapped` shim that injects the sops-decoded values from
`coding-agents.yaml` into the agent's environment.
