{ config, host, ... }:
let
  identity = host.machine.identity;
  user = identity.name;

  # Login keys. sshd reads these from /etc/ssh/nix_authorized_keys.d/<user>
  # through the AuthorizedKeysCommand in
  # /etc/ssh/sshd_config.d/101-authorized-keys.conf, so they work even though
  # this host has no ~/.ssh/authorized_keys.
  #
  # The first key is the install authorizer pinned by modules/nixos/system.nix
  # and config/hosts/intake/*.json. Its private half is on no reachable machine,
  # so it cannot authenticate anything, but it stays listed so the reviewed
  # enrollment artifacts remain consistent. Changing it means re-enrolling, not
  # editing this list.
  #
  # The second is the identity home-manager installs on every host at
  # ~/.ssh/id_github, and at ~/.ssh/id_ed25519 when that path is free. That is
  # the key a machine actually presents, so it is what login has to accept.
  # See docs/service-notes/github-ssh-key.md.
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPoWsO0x+p0FKVKOrfHPc0xeZuOZyMapMt8LxPbWHtb5"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOML7rbzZQUicy279UWUYh/7bPEr8OyUqk16kDgStJn+ mei@nixos-thinkpad-machine0"
  ];
in
{
  imports = [ ./dock ];

  users.users.${user} = {
    name = user;
    isHidden = false;
    openssh.authorizedKeys.keys = keys;
  };

  # Root takes the same keys because deploy-rs (modules/flake/deploy-rs.nix)
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
