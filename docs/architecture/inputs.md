# Extra flake inputs

`flake.nix` holds the core inputs (nixpkgs, den, flake-parts, import-tree,
home-manager, darwin, sops-nix, disko, deploy-rs) plus a small set of extras.
Each extra is selected by an aspect, so a host only pays for what its aspects
ask for.

## stylix

`github:danth/stylix`, for declarative system-wide theming. The aspect lives in
`modules/aspects/stylix.nix` and stays behind `stylix.enable = false`
until a host picks a palette and a font in `stylix.targets.<host>.colors` and
`stylix.targets.<host>.fonts`.

## nix-direnv

`github:nix-community/nix-direnv`. The aspect in
`modules/aspects/nix-direnv.nix` imports
`inputs.nix-direnv.nixosModules.default` and enables `programs.nix-direnv` on
every NixOS host. It pairs with the `use flake` line in `.envrc`.

## nh

`github:viperML/nh`, a replacement for `nixos-rebuild` and `home-manager` with
activation-diff review and `flake.lock` awareness. It is exposed as a flake app
and is the day-2 switch tool.

## preservation

`github:nix-community/preservation`. The aspect in
`modules/aspects/preservation.nix`, wired in from
`modules/aspects/linux.nix`, keeps `/etc/machine-id`, `/etc/ssh`,
`/var/lib`, `/var/db`, `/var/log`, `/srv`, `/home`, and `/root` from churning
across rebuilds through bind mounts. NixOS only; Darwin skips it.

## Consumed by an aspect

`zen-browser`, `spicetify-nix`, `helium`, and `noctalia` are read by the aspect
that owns their behavior. `multiverse` is added by `zix` when the first version
pin is created, and the pin overlay in `lib/nixpkgs.nix` applies it.
