# Declarative browser choices on standalone Linux

This repo now declares:

- `brave`

## Not yet declared from locked nixpkgs

The following requested browser packages were **not present** in the repo's
currently locked nixpkgs input during migration:

- `zen-browser`
- `helium`

That means `zen-browser` needed a separate flake source. `helium` is no longer
declared by this repo now that the custom overlay package was removed.

Only the following now remain host-managed unless you later add another source:

1. `zen-browser` profile data
2. `helium` profile data

## Why browser profiles are not committed

The live browser config directories contain secrets and state such as:

- cookies
- login/session databases
- browsing history
- bookmarks and sync state
- extension storage

Those profiles are not safe to commit wholesale into this repo. The current
declarative boundary is package choice, not full profile replication.
