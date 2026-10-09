{ den, ... }:
{
  den.aspects.pending-x86-workstation-hardware =
    { host, ... }:
    let
      machine = host.machine;
    in
    assert machine.boot.state == "disabled";
    {
    includes = [ den.aspects.workstation-role-linux ];
    nixos.boot.initrd.enable = false;
    };
}
