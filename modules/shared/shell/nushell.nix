{ ... }:
{
  # Nushell is the interactive login shell. Bash remains the fallback for
  # activation scripts and recovery.
  nushell = {
    enable = true;
    # Adopt the 26.11 default: source the Home Manager session environment in
    # env.nu so Nushell sees home.sessionVariables and home.sessionPath even
    # when the launcher did not inherit them.
    loadSessionVariables = true;
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
      #
      # Elevation tools live outside the store. NixOS keeps the setuid sudo
      # wrapper in /run/wrappers/bin and only prefixes that directory in
      # /etc/set-environment, which Nushell does not source. The standalone
      # host keeps its system profile in /run/system-manager/sw/bin, and the
      # foreign distros put sudo and run0 in /usr/bin. IDE terminals, TTY
      # logins, and sandboxes all hand Nushell a reduced environment, so the
      # three directories are listed here instead of inherited.
      $env.PATH = ([
        ($env.HOME | path join ".nix-profile/bin")
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
        ($env.HOME | path join ".npm-packages/bin")
        ($env.HOME | path join "bin")
        ($env.HOME | path join ".local/bin")
        "/run/wrappers/bin"
        "/run/system-manager/sw/bin"
        "/usr/bin"
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

      # Herdr and Kitty graphics terminals keep image placements when the text
      # screen clears, so the Fastfetch image survives Ctrl+L on its own. Delete
      # the Kitty image data before clearing the screen and scrollback.
      def clear-terminal [] {
        ^printf '\x1b_Ga=d,d=A\x1b\\\x1b[H\x1b[2J\x1b[3J'
      }
      alias clear = clear-terminal
      $env.config.keybindings = (($env.config.keybindings? | default []) | append {
        name: clear-terminal
        modifier: control
        keycode: char_l
        mode: [emacs, vi_normal, vi_insert]
        event: { send: executehostcommand, cmd: "clear-terminal" }
      })

      # Powerlevel10k only runs in zsh. This file builds the same lean prompt in
      # Nushell; see ../config/nushell/prompt.nu.
      source ${../config/nushell/prompt.nu}
    '';
    shellAliases = {
      pn = "pnpm";
      px = "pnpx";
      diff = "difft";
    };
  };
}
