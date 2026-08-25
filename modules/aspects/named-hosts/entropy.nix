{ den, ... }:
{
  den.aspects.entropy =
    { host, ... }:
    let
      machine = host.machine;
    in
    assert machine.target == "darwinConfigurations.${host.name}";
    assert machine.system == host.system;
    assert machine.role == "workstation";
    {
    includes = [
      den.aspects.entropy-storage
      den.aspects.entropy-device-capability-routing
    ];

    darwin =
      { lib, ... }:
      {
        networking.hostName = lib.mkForce machine.hostId;
        time.timeZone = lib.mkForce machine.location.timeZone;
        environment.variables.LANG = lib.mkForce machine.location.locale;
        users.users.${machine.identity.name}.home = lib.mkForce machine.identity.home;
      };
    };
}
