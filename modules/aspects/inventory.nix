{ ... }:
let
  linuxIdentity = {
    name = "mei";
    home = "/home/mei";
    uid = 1000;
    gid = 100;
  };
  # The NixOS hosts share the `users` group at gid 100. The standalone host has
  # a user-private primary group, so its home identity carries that gid.
  massivePrimaryGid = 1000;
  massiveIdentity = linuxIdentity // {
    gid = massivePrimaryGid;
  };
  darwinIdentity = {
    name = "mei";
    home = "/Users/mei";
    uid = 501;
    gid = 20;
  };
in
{
  den.hosts = {
    x86_64-linux = {
      remembrance.users.mei.identity = linuxIdentity;
      antagony.users.mei.identity = linuxIdentity;
    };
    aarch64-darwin.entropy.users.mei.identity = darwinIdentity;
  };
  den.homes = {
    x86_64-linux.massive = {
      userName = "mei";
      homeDirectory = "/home/mei";
      identity = massiveIdentity;
    };
  };
}
