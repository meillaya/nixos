Place local sops-encrypted secret files in this directory when needed.

This directory is intentionally ignored by git (except for this file and
`coding-agents.yaml`) so the public flake can bootstrap on fresh Linux
installs without fetching a private GitHub secrets repository during
evaluation.

The single tracked file is `coding-agents.yaml`, encrypted with `sops-nix`
using the two age recipients declared in `../.sops.yaml`.

For per-tool runtime API keys (OpenAI, Anthropic, etc.), use the
`codex-wrapped` shim that injects the sops-decoded values from
`coding-agents.yaml` into the agent's environment.
