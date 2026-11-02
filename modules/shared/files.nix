{ pkgs, config, lib, ... }:

let
  homeDirectory = config.home.homeDirectory;
  # Authoritative GitHub authentication key (public half only). The private half
  # is escrowed in the sops store secrets/github-ssh.yaml and installed at
  # ~/.ssh/id_github (and ~/.ssh/id_ed25519 when that path is still free) by
  # home.activation.installGithubSshKey. The public half lives in lib/keys.nix.
  githubPublicKey = (import ../../lib/keys.nix).github;
in
{
  ".npmrc" = {
    text = ''
      prefix=${homeDirectory}/.local
    '';
  };

  ".config/fastfetch" = {
    source = ../shared/config/fastfetch;
    recursive = true;
  };

  ".ssh/id_github.pub" = {
    text = githubPublicKey;
    # force: replace the manual `id_github.pub -> id_ed25519.pub` symlink that
    # predates the declaration, and follow any future rotation of the key
    # without leaving the old public half behind.
    force = true;
  };
}
