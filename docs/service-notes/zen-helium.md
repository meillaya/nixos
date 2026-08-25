# Zen on standalone Linux

## Zen

This repo now integrates Zen declaratively via the community Nix flake:

- `github:0xc000022070/zen-browser-flake`

On standalone Linux, the package is added through:

- `inputs.zen-browser.packages.${pkgs.system}.default`

This gives you a declarative Zen install even though your locked nixpkgs input
itself did not contain a `zen-browser` package.

Source used:
- https://github.com/0xc000022070/zen-browser-flake
- https://github.com/zen-browser

## Helium

Helium is no longer declared by this repo. The old local overlay package was
removed along with the rest of the custom overlay surface. If you still want
Helium on standalone Linux, install it outside this repo or add a new upstream
package source.
