{ pkgs, lib, ... }:
{
  # Bash is the fallback shell and the shell used by activation scripts.
  # Nushell is the interactive login shell; see ./nushell.nix.
  readline = {
    enable = true;
    variables = {
      completion-ignore-case = true;
      show-all-if-ambiguous = true;
      colored-stats = true;
      mark-symlinked-directories = true;
      menu-complete-display-prefix = true;
    };
    bindings = {
      "\\e[A" = "history-search-backward";
      "\\e[B" = "history-search-forward";
      "\\eOA" = "history-search-backward";
      "\\eOB" = "history-search-forward";
    };
  };

  bash = {
    enable = true;
    # macOS still ships /bin/bash 3.2, which does not understand Home
    # Manager's bash-completion guard (`[[ -v ... ]]`) or newer shopts.
    enableCompletion = !pkgs.stdenv.hostPlatform.isDarwin;
    shellOptions = [ "histappend" "extglob" ]
      ++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ "globstar" "checkjobs" ];
    historyControl = [ "ignoreboth" "erasedups" ];
    historyIgnore = [ "pwd" "ls" "cd" ];
    shellAliases = {
      pn = "pnpm";
      px = "pnpx";
      diff = "difft";
      search = "rg -p --glob '!node_modules/*'";
    } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      grep = "grep --color=auto";
      ls = "ls --color=auto";
    } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      ls = "ls -G";
    };
    bashrcExtra = ''
      if [[ $- == *i* && -t 1 && "''${TERM:-}" != "dumb" && "''${FASTFETCH_INIT_PID:-}" != "$$" ]] && command -v fastfetch >/dev/null 2>&1; then
        export FASTFETCH_INIT_PID=$$
        fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
        echo
      fi
    '';
    initExtra = ''
      if [[ "$(uname)" == Linux && -n "''${WAYLAND_DISPLAY-}" ]]; then
        current_display="''${DISPLAY-}"
        current_socket=""
        if [[ -n "$current_display" && "$current_display" == :* ]]; then
          display_num="''${current_display#:}"
          display_num="''${display_num%%.*}"
          current_socket="/tmp/.X11-unix/X$display_num"
        fi
        if [[ -z "$current_display" || ! -S "$current_socket" ]]; then
          if [[ -S /tmp/.X11-unix/X0 ]]; then
            export DISPLAY=:0
          fi
        fi
      fi

      if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      export PATH=$HOME/.npm-packages/bin:$HOME/bin:$PATH
      export PATH=$HOME/.local/bin:$PATH

      export EDITOR="micro"
      export VISUAL="zeditor"

      [[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"
      [[ -f "$HOME/.ghcup/env" ]] && . "$HOME/.ghcup/env"

      e() {
          micro "$@"
      }

      shell() {
          nix-shell '<nixpkgs>' -A "$1"
      }

      fastfetch() {
          # Always route through the rich system profile (Snoopy image + full
          # module set). Pass through --config/-c when explicitly requested.
          if [[ "$*" == *-c* || "$*" == *--config* ]]; then
              command fastfetch "$@"
          else
              command fastfetch --config "$HOME/.config/fastfetch/config.jsonc" "$@"
          fi
      }
    '';
  };
}
