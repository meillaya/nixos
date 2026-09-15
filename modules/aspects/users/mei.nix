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
        # Agent multiplexer (herdr.dev). From our own pin: current
        # nixos-unstable carries herdr, so no extra flake input is needed.
        pkgs.herdr
        ((pkgs.writeShellScriptBin "codex-wrapped" ''
          set -euo pipefail
          export SOPS_AGE_KEY_FILE="${config.home.homeDirectory}/.config/sops/age/keys.txt"
          SECRETS_FILE="${config.home.homeDirectory}/nixos/secrets/coding-agents.yaml"
          exec sops exec-env "$SECRETS_FILE" -- codex "$@"
        '') // { pname = "codex-wrapped"; })
      ];
      gtk.gtk4.theme = config.gtk.theme;
      home.file = import ../../shared/files.nix { inherit config pkgs lib; };

      # `programs.git.signing` (in shared/home-manager.nix) points at
      # ~/.ssh/git_signing_ed25519.pub and sets commit.gpgsign = true, but nothing
      # ever created the keypair. On a fresh machine every commit fails with
      # "Couldn't load public key ~/.ssh/git_signing_ed25519.pub: No such file or
      # directory".
      #
      # The key is generated rather than shipped because it is per-machine
      # identity: never regenerate over an existing key, so the identity stays
      # stable across activations. The public half is kept in allowed_signers so
      # `git log --show-signature` verifies without an "Unable to open allowed keys
      # file" warning (gpg.ssh.allowedSignersFile points there too).
      home.activation.setupGitSigningKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        key="${config.home.homeDirectory}/.ssh/git_signing_ed25519"
        allowed="${config.home.homeDirectory}/.ssh/allowed_signers"
        sshdir="${config.home.homeDirectory}/.ssh"

        if [ ! -f "$key" ]; then
          $VERBOSE_ECHO "git-signing: generating $key"
          mkdir -p "$sshdir"
          chmod 700 "$sshdir"
          $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen \
            -t ed25519 \
            -f "$key" \
            -N "" \
            -C "git signing key"
          chmod 600 "$key"
          chmod 644 "$key.pub"
        fi

        # Refresh allowed_signers when it is missing or has drifted, so
        # verification always matches the live key.
        if [ ! -f "$allowed" ] || ! grep -qF "$(cat "$key.pub")" "$allowed"; then
          $VERBOSE_ECHO "git-signing: refreshing $allowed"
          $DRY_RUN_CMD printf '%s %s\n' "nathanagbomed@proton.me" "$(cat "$key.pub")" > "$allowed"
          chmod 644 "$allowed"
        fi
      '';
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
