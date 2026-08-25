{ den, ... }:
{
  den.aspects.bootstrap-password = { host, ... }: {
    nixos.imports = [
      (import ../../nixos/bootstrap-password.nix { identity = host.machine.identity; })
    ];
  };
}
