# Flake inputs

`flake.nix` holds the core inputs and the feature inputs that an enabled module
actually reads.

## Core

- `nixpkgs`: the fleet package pin.
- `den`, `flake-parts`, `import-tree`: the entity/aspect tree and the
  per-system outputs. Den is the composition and learning layer.
- `home-manager` and `darwin`: the two Home Manager and nix-darwin module sets,
  both following the fleet nixpkgs.
- `sops-nix`: the encrypted secret store.
- `flake-compat`: shared by helium, so its consumer can follow one node.

## Feature inputs

- `zen-browser`, `spicetify-nix`, and `helium`: the browser, music, and
  font-wrapped browser packages.
- `noctalia`: the desktop shell. It keeps an independent nixpkgs pin so its
  Cachix artifacts remain usable; zix passes `-I noctalia` to auto-follow for
  the same reason.
- `nix-plist-manager`: the macOS preference writer. It is the only author of
  the keys it manages; `system.defaults` covers the remainder.
- `system-manager`: the system layer for `massive`, covering the hostname,
  tailscaled, GPU driver path, Nix settings, data disk, login account and shell,
  PAM helper wrapper, CachyOS package bootstrap, SDDM theme, and OpenRGB udev
  integration.
- `multiverse`: the version index zix uses for real package pins (currently
  raycast). It is a developer-tool input; the overlay is empty when
  `zix/managed/pins.json` is empty.

## The distro

`distro/flake.nix` has its own lock. It consumes this flake as `nixos-config`
and pins the same nixpkgs revision explicitly, because a path input does not
carry its own lock into the consumer. It builds the live ISO and the installed
closure by extending `nixosConfigurations.remembrance`.

## Removed inputs

The following were declared but not doing useful work and have been removed:

- `stylix`: the aspect set `stylix.enable = false`.
- `preservation`: no host set `preserveAt`.
- `emacs-overlay`: Emacs is not installed.
- `nh`: `pkgs.nh` provides the same command without a root input.
- `deploy-rs`: the flake no longer exposes deploy nodes; use
  `nix run nixpkgs#deploy-rs` or `nixos-rebuild --target-host` when needed.
- `ghostty`: nixpkgs carries the package; macOS uses the local
  `pkgs/ghostty-bin.nix` overlay.
- `systems`: it existed only to deduplicate stylix's systems node.

## zix

zix is a developer tool. It is exposed as `nix run .#zix`, has a dev-shell
function, and still owns `zix/managed/`. It is not installed in any host
package closure.
