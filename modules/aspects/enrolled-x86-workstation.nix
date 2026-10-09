# Enrolled x86 workstation hardware baseline.
#
# A host whose machine record is enrolled (boot.state == "uefi") gets the full
# workstation role with the initrd left at its default (enabled). This is the
# enrolled counterpart to `pending-x86-workstation-hardware`, which asserts the
# pending state and disables the initrd while a host awaits enrollment.
{ den, ... }:
{
  den.aspects.enrolled-x86-workstation-hardware =
    { host, ... }:
    let
      machine = host.machine;
    in
    assert machine.boot.state == "uefi";
    {
    includes = [ den.aspects.workstation-role-linux ];
    };
}
