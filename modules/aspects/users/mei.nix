{ den, inputs, ... }:
let
  osIdentity =
    { host, user, ... }:
    let
      inherit (user) identity;
    in
    {
      name = "machine-identity/${identity.name}@${host.name}";

      nixos =
        { pkgs, ... }:
        {
          environment.shells = with pkgs; [ nushell bashInteractive zsh fish ];
          users.users.${identity.name}.shell = pkgs.nushell;
        };

      darwin =
        { pkgs, lib, ... }:
        {
          environment.shells = with pkgs; [ nushell bashInteractive zsh fish ];
          users.users.${identity.name}.shell = pkgs.nushell;

          # The primary admin is intentionally not a nix-darwin managed user,
          # so reconcile only its shell without taking account ownership.
          system.activationScripts.postActivation.text = lib.mkAfter ''
            desired_shell=/run/current-system/sw/bin/nu
            if [[ ! -x "$systemConfig/sw/bin/nu" ]]; then
              printf >&2 'error: configured Nushell is not executable: %s\n' "$systemConfig/sw/bin/nu"
              exit 1
            fi

            current_shell=$(/usr/bin/dscl . -read /Users/${identity.name} UserShell)
            current_shell="''${current_shell#UserShell: }"
            if [[ "$current_shell" != "$desired_shell" ]]; then
              /usr/bin/dscl . -create /Users/${identity.name} UserShell "$desired_shell"
            fi
          '';
        };
    };
in
{
  den.aspects.mei = {
    includes = [
      den.batteries.define-user
      den.batteries.primary-user
      osIdentity
    ];

    homeManager = { config, pkgs, lib, ... }: {
      # Declarative Zen Browser (shared fragment drives identical spaces, pins,
      # settings, policies, and shortcuts on every host with the mei user).
      # Cross-machine parity comes from the stable space/pin ids in the
      # fragment, never from profile-folder copying.
      imports = [
        inputs.zen-browser.homeModules.beta
        (import ../../shared/config/zen.nix)
      ];
      home.packages = [
        ((pkgs.writeShellScriptBin "codex-wrapped" ''
          set -euo pipefail
          export SOPS_AGE_KEY_FILE="${config.home.homeDirectory}/.config/sops/age/keys.txt"
          SECRETS_FILE="${config.home.homeDirectory}/nixos/secrets/coding-agents.yaml"
          exec sops exec-env "$SECRETS_FILE" -- codex "$@"
        '') // { pname = "codex-wrapped"; })
      ];
      gtk.gtk4.theme = config.gtk.theme;
      home.file = import ../../shared/files.nix { inherit config pkgs lib; };
      programs = (import ../../shared/home-manager.nix { inherit config pkgs lib; }) // {
        nushell = {
          enable = true;
          settings = {
            show_banner = false;
            show_hints = true;
            history = {
              file_format = "sqlite";
              max_size = 100000;
              sync_on_enter = true;
              isolation = false;
            };
            completions.algorithm = "fuzzy";
            color_config.hints = "light_cyan";
          };
          extraEnv = ''
            $env.PATH = ([
              ($env.HOME | path join ".nix-profile/bin")
              ($env.HOME | path join ".kimi-code/bin")
              "/home/mei/.opencode/bin"
              "/run/current-system/sw/bin"
              "/nix/var/nix/profiles/default/bin"
            ] | append $env.PATH | uniq)
          '';
          extraConfig = ''
            if $nu.is-interactive and (($env.TERM? | default "") != "dumb") and (which fastfetch | is-not-empty) {
              fastfetch --config ($env.HOME | path join ".config/fastfetch/config.jsonc")
              print ""
            }
          '';
          shellAliases = {
            pn = "pnpm";
            px = "pnpx";
            diff = "difft";
          };
        };
      };
    };
  };
}
