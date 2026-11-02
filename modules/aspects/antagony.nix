{ den, ... }:
{
  den.aspects.antagony =
    { host, ... }:
    let
      identity = host.users.mei.identity;
    in
    {
      includes = [
        den.aspects.workstation-role-linux
        den.aspects.storage-labels
      ];
      nixos =
        { ... }:
        {
          networking.hostName = host.hostName;
          time.timeZone = "America/New_York";
          i18n.defaultLocale = "en_US.UTF-8";
          console.keyMap = "us";
          services.xserver.xkb.layout = "us";

          users.users.${identity.name} = {
            uid = identity.uid;
            home = identity.home;
          };
          users.groups.users.gid = identity.gid;
        };
    };
}
