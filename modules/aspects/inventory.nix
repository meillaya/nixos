{ ... }:
let
  linuxIdentity = {
    name = "mei";
    home = "/home/mei";
    uid = 1000;
    gid = 100;
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
      live.users.mei.identity = linuxIdentity;
      installed.users.mei.identity = linuxIdentity;
    };
    aarch64-darwin.entropy.users.mei.identity = darwinIdentity;
  };
  den.homes = {
    x86_64-linux.massive = {
      userName = "mei";
      homeDirectory = "/home/mei";
    };
  };
}
