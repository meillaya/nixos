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
        { ... }:
        {
          networking.hostName = host.hostName;
          time.timeZone = "America/New_York";
          environment.variables.LANG = "en_US.UTF-8";
          users.users.${identity.name}.home = identity.home;
        };
    };
}
