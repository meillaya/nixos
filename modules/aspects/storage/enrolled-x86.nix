# Enrolled x86 storage: wires the Disko layout for an enrolled host.
#
# A host whose machine record is enrolled (storage.profile == "single-gpt-btrfs")
# activates the reviewed, host-bound Disko layout by enabling
# `nixConfig.storage`. This includes the `storage` feature aspect, which imports
# the Disko module and `modules/nixos/disk-config.nix` (the option definitions);
# without it `nixConfig.storage` would not exist in the evaluation.
{ den, ... }:
{
  den.aspects.enrolled-x86-storage =
    { host, ... }:
    let
      machine = host.machine;
    in
    assert machine.storage.profile == "single-gpt-btrfs";
    {
    includes = [ den.aspects.storage ];
    nixos =
      { lib, ... }:
      {
        nixConfig.storage.enable = true;
        nixConfig.storage.hostId = lib.mkForce machine.hostId;
        nixConfig.storage.diskById = lib.mkForce machine.storage.diskById;
      };
    };
}
