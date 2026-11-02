{ config, host, ... }:
let
  identity = host.users.mei.identity;
  user = identity.name;

  # Login keys. sshd reads these from /etc/ssh/nix_authorized_keys.d/<user>
  # through the AuthorizedKeysCommand in
  # /etc/ssh/sshd_config.d/101-authorized-keys.conf, so they work even though
  # this host has no ~/.ssh/authorized_keys.
  #
  # This is the identity home-manager installs on every host at
  # ~/.ssh/id_github, and at ~/.ssh/id_ed25519 when that path is free. That is
  # the key a machine actually presents, so it is what login has to accept.
  # See docs/service-notes/github-ssh-key.md.
  keys = [ (import ../../lib/keys.nix).github ];
in
{
  imports = [ ./dock ];

  users.users.${user} = {
    name = user;
    isHidden = false;
    openssh.authorizedKeys.keys = keys;
  };

  # Root takes the same key for remote deployment and host-to-host SSH.
  # macOS leaves PermitRootLogin at OpenSSH's `prohibit-password`, which admits
  # exactly this and still refuses passwords.
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
