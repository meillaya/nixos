{ config, host, ... }:
let
  identity = host.machine.identity;
  user = identity.name;

  # The fleet login key, mirroring modules/nixos/system.nix. sshd reads it from
  # /etc/ssh/nix_authorized_keys.d/<user> through the AuthorizedKeysCommand in
  # /etc/ssh/sshd_config.d/101-authorized-keys.conf, so this works even though
  # this host has no ~/.ssh/authorized_keys.
  keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPoWsO0x+p0FKVKOrfHPc0xeZuOZyMapMt8LxPbWHtb5" ];
in
{
  imports = [ ./dock ];

  users.users.${user} = {
    name = user;
    isHidden = false;
    openssh.authorizedKeys.keys = keys;
  };

  # Root takes the same key because deploy-rs (modules/flake/deploy-rs.nix)
  # activates as root. macOS leaves PermitRootLogin at OpenSSH's
  # `prohibit-password`, which admits exactly this and still refuses passwords.
  users.users.root.openssh.authorizedKeys.keys = keys;

  local.dock = {
    enable = true;
    username = user;
    entries = [
      { path = "/Applications/Safari.app/"; }
      { path = "/System/Applications/Messages.app/"; }
      { path = "/System/Applications/Notes.app/"; }
      { path = "/System/Applications/Music.app/"; }
      { path = "/System/Applications/Photos.app/"; }
      { path = "/System/Applications/Photo Booth.app/"; }
      { path = "/System/Applications/System Settings.app/"; }
      {
        path = "${config.users.users.${user}.home}/Downloads";
        section = "others";
        options = "--sort name --view grid --display stack";
      }
    ];
  };
}
