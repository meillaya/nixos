{ den, ... }:
{
  den.aspects.entropy =
    { host, ... }:
    let
      identity = host.users.mei.identity;
    in
    {
      includes = [ den.aspects.workstation-role-darwin ];
      darwin =
        { lib, ... }:
        {
          networking.hostName = lib.mkForce host.hostName;
          time.timeZone = lib.mkForce "America/New_York";
          environment.variables.LANG = lib.mkForce "en_US.UTF-8";
          users.users.${identity.name}.home = lib.mkForce identity.home;
        };
    };
}
