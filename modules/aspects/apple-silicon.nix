{ den, ... }:
{
  den.aspects.apple-silicon-hardware =
    { host, ... }:
    let
      machine = host.machine;
    in
    assert machine.system == host.system;
    assert machine.cpuVendor == "Apple";
    {
    includes = [ den.aspects.workstation-role-darwin ];
    darwin.assertions = [
      {
        assertion = machine.cpuVendor == "Apple";
        message = "aarch64-darwin hardware authority must remain Apple silicon";
      }
    ];
    };
}
