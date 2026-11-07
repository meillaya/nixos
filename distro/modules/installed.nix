# The installed profile is the real workstation configuration.
#
# The flake builds this profile by extending nixosConfigurations.remembrance.
# The hostname, timezone, keyboard, kernel, user services, and SSH keys come
# from the host aspect, so the first boot is the named host. This module keeps
# the one setting the distro requires: SSH stays enabled for administration.
{ lib, ... }:
{
  services.openssh.enable = lib.mkForce true;
}
