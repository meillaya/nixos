{ ... }:
let
  authority = import ./_machine-authority/model.nix;
  machineFor = authority.getMachine;

  laptop = machineFor "remembrance";
  antagony = machineFor "antagony";
  darwinArm = machineFor "entropy";
in
assert laptop.target == "nixosConfigurations.remembrance";
assert antagony.target == "nixosConfigurations.antagony";
assert darwinArm.target == "darwinConfigurations.entropy";
{
  den.hosts = {
    x86_64-linux = {
      remembrance = {
        system = "x86_64-linux";
        hostName = laptop.hostId;
        machine = laptop;
        users.${laptop.identity.name}.identity = laptop.identity;
      };
      antagony = {
        system = "x86_64-linux";
        hostName = antagony.hostId;
        machine = antagony;
        users.${antagony.identity.name}.identity = antagony.identity;
      };
    };
    aarch64-darwin = {
      entropy = {
        system = "aarch64-darwin";
        hostName = darwinArm.hostId;
        machine = darwinArm;
        users.${darwinArm.identity.name}.identity = darwinArm.identity;
      };
    };
  };
  den.homes = {
    x86_64-linux.standalone-linux = {
      machine = laptop;
      userName = laptop.identity.name;
      homeDirectory = laptop.identity.home;
    };
  };
}
