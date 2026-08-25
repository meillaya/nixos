{ den, ... }:
{
  den.aspects.remembrance-storage =
    { host, ... }:
    let
      machine = host.machine;
    in
    assert machine.storage.profile == "none";
    {
    includes = [
      den.aspects.pending-x86-workstation-hardware
      den.aspects.remembrance-hardware-routing
    ];
    nixos.assertions = [
      {
        assertion = machine.storage.profile == "none";
        message = "remembrance storage must remain disabled until enrollment";
      }
    ];
    };
}
