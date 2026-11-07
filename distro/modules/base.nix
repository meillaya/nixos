# Shared identity for the live and installed distro profiles.
#
# The installed profile is the real workstation configuration. Only the live
# medium needs the personal overrides in live.nix, so this module keeps the
# pieces both profiles need: the distro identity options, the user the installer
# sets a password for, and a mutable account database.
{ config, ... }:
let
  user = config.distro.liveUser;
in
{
  imports = [ ./identity.nix ];

  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "i2c"
    ];
  };
  users.mutableUsers = true;
}
