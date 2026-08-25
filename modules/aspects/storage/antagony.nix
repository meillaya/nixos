{ den, ... }:
{
  den.aspects.antagony-storage =
    { host, ... }:
    let
      machine = host.machine;
    in
    assert machine.storage.profile == "none";
    {
    includes = [
      den.aspects.pending-x86-workstation-hardware
      den.aspects.antagony-hardware-routing
    ];
    nixos.assertions = [
      {
        assertion = machine.storage.profile == "none";
        message = "antagony storage must remain disabled until enrollment";
      }
    ];
    };
}