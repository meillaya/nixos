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
        { lib, ... }:
        {
          networking.hostName = lib.mkForce host.hostName;
          time.timeZone = lib.mkForce "America/New_York";
          i18n.defaultLocale = lib.mkForce "en_US.UTF-8";
          console.keyMap = lib.mkForce "us";
          services.xserver.xkb.layout = lib.mkForce "us";

          users.users.${identity.name} = {
            uid = lib.mkForce identity.uid;
            home = lib.mkForce identity.home;
          };
          users.groups.users.gid = lib.mkForce identity.gid;
        };
    };
}
