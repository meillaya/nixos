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
        (import ../shared/config/zen.nix)
      ];
      home.packages = [
        # Herdr agent multiplexer; nixpkgs currently provides the latest release.
        pkgs.herdr
      ];
      gtk.gtk4.theme = config.gtk.theme;
      home.file = import ../shared/files.nix { inherit config pkgs lib; };

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

      # Authoritative GitHub SSH key. The keypair is escrowed in
      # `secrets/github-ssh.yaml` (sops/age, tracked in the repo), so every host
      # reaches the same GitHub identity through `home-switch` / `build-switch`
      # instead of a hand-copied key. `id_github` is the identity the shared SSH
      # config tries first for github.com; `id_ed25519` is the path
      # `sops.age.sshKeyPaths` and the enrollment tooling already expect, so it
      # is filled in only when it does not exist; an existing per-machine key is
      # never overwritten, because it may be that machine's age identity.
      #
      # Decrypting needs an age identity: `$SOPS_AGE_KEY_FILE`, else
      # ~/.config/sops/age/keys.txt (the `&workstation` recipient). Without one
      # the step warns and leaves the machine untouched instead of failing the
      # switch. The store must be git-tracked before the first switch: flake
      # evaluation only sees tracked files, and this is a path literal.
      home.activation.installGithubSshKey =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          store=${../../secrets/github-ssh.yaml}
          identity="''${SOPS_AGE_KEY_FILE:-${config.home.homeDirectory}/.config/sops/age/keys.txt}"
          sshdir="${config.home.homeDirectory}/.ssh"
          key="$sshdir/id_github"
          legacy="$sshdir/id_ed25519"

          if [ ! -f "$identity" ]; then
            printf '%s\n' "github-ssh-key: no age identity at $identity; skipping (place keys.txt or set SOPS_AGE_KEY_FILE, then re-run activation)" >&2
          else
            tmp="$(mktemp)"
            pub="$(mktemp)"
            chmod 600 "$tmp"  # ssh-keygen refuses group/world-readable keys

            if SOPS_AGE_KEY_FILE="$identity" ${pkgs.sops}/bin/sops --input-type yaml --output-type binary --decrypt --extract '["github-ssh-private-key"]' "$store" > "$tmp" 2>/dev/null \
              && [ -s "$tmp" ] \
              && ${pkgs.openssh}/bin/ssh-keygen -y -f "$tmp" > "$pub" 2>/dev/null; then
              chmod 644 "$pub"
              mkdir -p "$sshdir"
              chmod 700 "$sshdir"

              if [ ! -f "$key" ] || ! cmp -s "$tmp" "$key"; then
                $VERBOSE_ECHO "github-ssh-key: installing $key"
                $DRY_RUN_CMD install -m 600 "$tmp" "$key"
              fi

              if [ ! -e "$legacy" ]; then
                $VERBOSE_ECHO "github-ssh-key: installing $legacy"
                $DRY_RUN_CMD install -m 600 "$tmp" "$legacy"
                $DRY_RUN_CMD install -m 644 "$pub" "$legacy.pub"
              fi
            else
              printf '%s\n' "github-ssh-key: could not decrypt or validate secrets/github-ssh.yaml with $identity; leaving $key alone" >&2
            fi

            rm -f "$tmp" "$pub"
          fi
        '';
      programs = (import ../shared/home-manager.nix { inherit config pkgs lib; }) // {
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
            # User-installed tools (dsh, hermes, ...) live in ~/.local/bin.
            # bash/zsh/fish all add these explicitly, but nushell did not: it
            # only saw them when launched from a login shell. A GUI-launched
            # kitty inherits launchd's minimal PATH, so `dsh` was unrecognised
            # while `node` still worked via fnm. Listed here so nushell never
            # depends on what happened to launch it.
            $env.PATH = ([
              ($env.HOME | path join ".nix-profile/bin")
              "/run/current-system/sw/bin"
              "/nix/var/nix/profiles/default/bin"
              ($env.HOME | path join ".npm-packages/bin")
              ($env.HOME | path join "bin")
              ($env.HOME | path join ".local/bin")
            ] | append $env.PATH | uniq)

            # Node comes from fnm (official prebuilt releases) rather than
            # nixpkgs: source-built Node breaks @deepseek-ai/dsh's native
            # require-builtin addon. See modules/shared/packages.nix.
            # fnm exports $FNM_MULTISHELL_PATH/bin, not the multishell root,
            # so the /bin suffix matters. Guarded so a broken fnm can never
            # block shell startup.
            try {
              if (which fnm | is-not-empty) {
                let fnm_env = (^fnm env --json | from json)
                load-env $fnm_env
                $env.PATH = ($env.PATH | prepend ($fnm_env.FNM_MULTISHELL_PATH | path join "bin"))
              }
            } catch { }
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
