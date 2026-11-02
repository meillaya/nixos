# Installed-system behavior on top of the shared label storage contract.
{ config, lib, ... }:
{
  networking.hostName = lib.mkForce config.distro.hostName;

  # SSH is available, but no key is trusted until the operator adds one.
  services.openssh.enable = lib.mkForce true;
}
