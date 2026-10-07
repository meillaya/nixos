# Homebrew-free Darwin migration

This repo is intended to manage the Darwin system with Nix, not Homebrew.
Use `mcp-nixos` and the unstable package index at
<https://search.nixos.org/packages?channel=unstable> for package lookup and
verification before adding new Darwin packages.

## Package lookup

`mcp-nixos` is installed by this config. For agent verification, use its NixOS
package search on the `unstable` channel before relying on a package name.
The package index URL above is the human-facing reference for the same channel.

## Before removing the existing Homebrew installation

Only remove the physical Homebrew tree after the Nix config has built, switched,
and the replacement apps work from their Nix-owned paths.

Read-only inventory commands:

```bash
brew list --cask
brew leaves --installed-on-request
brew services list
brew bundle dump --file "$HOME/Desktop/Brewfile.before-nix-only" --force
```

Do not use cask `zap` if preserving app data. Prefer the official uninstall
script only after inventory and replacement QA are complete.

## Post-switch app checks

```bash
find /Applications/Nix\ Apps -maxdepth 1 -name '*.app' -type d
mdls -name kMDItemCFBundleIdentifier "/Applications/Nix Apps/Foo.app"
mdfind 'kMDItemCFBundleIdentifier == "com.vendor.App"'
open "/Applications/Nix Apps/Foo.app"
```

Re-pin Dock aliases from the Nix-owned app bundle paths if macOS keeps pointing
at an old app location.

## Former cask decisions

No former app cask is deferred. The remaining apps have explicit non-Homebrew
management decisions:

The previous local Nix derivations for Helium, OmniWM, Stremio, and Sublime
Text were removed when repo-local overlays were deleted. If you still want any
of those apps managed declaratively, reintroduce them via upstream nixpkgs,
another flake input, or a separate dedicated repo.

The Darwin machine now exposes a real `build-switch` app (a `sudo darwin-rebuild
switch`), so repository verification is no longer build-only. App bundle
appearance under `/Applications/Nix Apps`, migration away from Homebrew, and
native activation remain not verified on the first switch. Build before
switching, and roll back with `sudo darwin-rebuild rollback`.
