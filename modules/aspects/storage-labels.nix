# The installed-system storage contract, shared by personal and distro hosts.
# No aspect owns a disk ID; the installer creates the labels this module reads.
{ den, ... }:
{
  den.aspects.storage-labels.nixos = import ../nixos/storage-labels.nix;
}
