{ inputs, ... }:
{
  den.aspects.sops = { host, ... }: {
    nixos = {
      imports = [
        inputs.sops-nix.nixosModules.default
      ];
      sops.age.sshKeyPaths = [ "${host.machine.identity.home}/.ssh/id_ed25519" ];
    };
    darwin = {
      imports = [
        inputs.sops-nix.darwinModules.default
      ];
      sops.age.sshKeyPaths = [
        "${host.machine.identity.home}/.ssh/id_ed25519"
      ];
    };
  };
}
