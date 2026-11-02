{ ... }:
{
  # Nushell is the interactive login shell. Bash remains the fallback for
  # activation scripts and recovery.
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
      # bash adds these explicitly, but nushell did not: it only saw them
      # when launched from a login shell. A GUI-launched kitty inherits
      # launchd's minimal PATH, so `dsh` was unrecognised while `node`
      # still worked via fnm. Listed here so nushell never depends on what
      # happened to launch it.
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
}
