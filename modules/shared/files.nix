{ pkgs, config, lib, ... }:

let
  homeDirectory =
    let
      hmHome = lib.attrByPath [ "home" "homeDirectory" ] null config;
      primaryUser =
        lib.attrByPath [ "home" "username" ]
          (lib.attrByPath [ "system" "primaryUser" ] null config)
          config;
      managedUserHome =
        if primaryUser == null then
          null
        else
          lib.attrByPath [ "users" "users" primaryUser "home" ] null config;
    in
    if hmHome != null then hmHome else if managedUserHome != null then managedUserHome else "$HOME";
  # Authoritative GitHub authentication key (public half only). The private half
  # is escrowed in the sops store secrets/github-ssh.yaml and installed at
  # ~/.ssh/id_github (and ~/.ssh/id_ed25519 when that path is still free) by
  # home.activation.installGithubSshKey. This declaration must track the sealed
  # key, or the ~/.ssh/id_github.pub this writes contradicts the private half.
  githubPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOML7rbzZQUicy279UWUYh/7bPEr8OyUqk16kDgStJn+ mei@nixos-thinkpad-machine0";
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

  # Pin the opencode plugin to the same oh-my-openagent version the repo
  # installs (5.0.0-beta.7). `@latest` would resolve to 4.19.4 on npm and
  # run the old plugin with its built-in model defaults, ignoring the 5.x
  # `~/.omo/omo.jsonc` config. Runtime changes (MCP servers, providers)
  # belong in opencode.json, which stays unmanaged.
  ".config/opencode/opencode.jsonc" = {
    text = builtins.readFile ../shared/config/opencode/opencode.jsonc;
    force = true;
  };

  ".ssh/id_github.pub" = {
    text = githubPublicKey;
    # force: replace the manual `id_github.pub -> id_ed25519.pub` symlink that
    # predates the declaration, and follow any future rotation of the key
    # without leaving the old public half behind.
    force = true;
  };

  # Initializes Emacs with org-mode so we can tangle the main config
  ".emacs.d/init.el" = {
    text = builtins.readFile ../shared/config/emacs/init.el;
  };

  # IMPORTANT: The Emacs configuration expects a config.org file at ~/.config/emacs/config.org
  # You can either:
  # 1. Copy the provided config.org to ~/.config/emacs/config.org
  # 2. Set EMACS_CONFIG_ORG environment variable to point to your config.org location
  # 3. Uncomment below to have Nix manage the file:
  #
  # ".config/emacs/config.org" = {
  #   text = builtins.readFile ../shared/config/emacs/config.org;
  # };

}
