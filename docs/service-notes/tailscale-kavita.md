# Tailscale + Kavita boundary notes

This repo owns:

- `tailscaled` as a system service, through `systemConfigs.massive` (see below)
- `calibre` as a Home Manager package

and tracks a Kavita appsettings template at:

- `modules/standalone-linux/templates/kavita-appsettings.example.json`

## What is intentionally not committed

The current live Kavita and Tailscale state contains secret or machine-specific
data that should not be versioned in the public repo, including:

- Kavita `TokenKey`
- any future OIDC secret
- Tailscale auth state / node identity
- browser or app cookies/session state
- Kavita database, cache, covers, and backup archives

## Current machine facts captured during migration

- `tailscale status` works on `entropyos`
- current machine had no active `tailscale serve` config
- current Kavita runtime settings were preserved into the template except for
  secret fields

## Recommended local secret workflow

Keep the real Kavita appsettings in an ignored local/secrets location and copy
from the template when provisioning a new machine.

Suggested local path:

- `secrets/kavita/appsettings.json`

Suggested bootstrap flow:

1. Copy `modules/standalone-linux/templates/kavita-appsettings.example.json`
2. Fill in `TokenKey` and any other secret values locally
3. Sync it into this repo's ignored `./secrets` tree with an explicit writable
   checkout: `nix run .#sync-secrets -- --repo-root "$PWD"`
4. Install it outside Nix evaluation:
   `install -Dm0600 secrets/kavita/appsettings.json "$HOME/Documents/Kavita/config/appsettings.json"`
5. Run `nix run .#home-switch` for non-secret declarative configuration only.

Standalone Home Manager intentionally does not inspect or manage this plaintext
file. The manual runtime destination is:

- `~/Documents/Kavita/config/appsettings.json`

## Why this is a boundary

Home Manager on non-NixOS Linux covers user-space packages and dotfiles only.
System-level state on the standalone host comes from `system-manager` instead:
`systemConfigs.massive`, built from `modules/standalone-linux/system.nix`, owns
the hostname and the `tailscaled` unit, and nothing else.

So the current repo boundary is: user space and one small, explicit system layer
are declarative; secrets and runtime service state are not.
