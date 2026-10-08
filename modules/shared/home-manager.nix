{ config, pkgs, lib, ... }:

let
    user = config.home.username or "mei";
    gitName = "Meillaya";
    gitEmail = "nathanagbomed@proton.me";

    # The identity home-manager installs on every host at ~/.ssh/id_github, and
    # at ~/.ssh/id_ed25519 when that path is free. Offering it to the fleet is
    # what makes host-to-host SSH work: every host authorizes this key for
    # login, and no host holds the older installer anchor it replaced.
    sshDir = if pkgs.stdenv.hostPlatform.isLinux then "/home/${user}/.ssh" else "/Users/${user}/.ssh";
    sshIdentity = [
      "${sshDir}/id_github"
      "${sshDir}/id_ed25519"
    ];
in
{
  # Shared shell configuration
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
      grep = "grep --color=auto";
      ls = "ls --color=auto";
      search = "rg -p --glob '!node_modules/*'";
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

  fish = {
    enable = true;
    # fish 4.8.0 dropped `share/fish/tools/create_manpage_completions.py`,
    # which home-manager's auto-generated completion step calls for every
    # package with a manpage. Disable until upstream lands a 4.8-compatible
    # generator. Static `share/fish/vendor_completions.d/` files still work;
    # add hand-rolled entries under `programs.fish.completions` as needed.
    generateCompletions = false;
    shellAliases = {
      pn = "pnpm";
      px = "pnpx";
      diff = "difft";
      ls = "ls --color=auto";
      search = "rg -p --glob '!node_modules/*'";
    };
    functions = {
      e.body = ''
        micro $argv
      '';
      shell.body = ''
        nix-shell '<nixpkgs>' -A $argv[1]
      '';
      fastfetch.body = ''
        # Always route through the rich system profile (Snoopy image + full
        # module set). Pass through --config/-c when explicitly requested.
        for arg in $argv
          switch $arg
            case -c --config '--config=*'
              command fastfetch $argv
              return
          end
        end
        command fastfetch --config "$HOME/.config/fastfetch/config.jsonc" $argv
      '';
    };
    shellInit = ''
      if test (uname) = Linux; and test -n "$WAYLAND_DISPLAY"
        set -l current_display "$DISPLAY"
        set -l current_socket ""
        if string match -rq '^:[0-9]+' -- "$current_display"
          set -l display_num (string replace -r '^:([0-9]+).*' '$1' -- "$current_display")
          set current_socket "/tmp/.X11-unix/X$display_num"
        end
        if test -z "$current_display"; or not test -S "$current_socket"
          if test -S /tmp/.X11-unix/X0
            set -gx DISPLAY :0
          end
        end
      end

      if test -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
      else if test -f /nix/var/nix/profiles/default/etc/profile.d/nix.fish
        source /nix/var/nix/profiles/default/etc/profile.d/nix.fish
      end

      if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
        source /usr/share/cachyos-fish-config/cachyos-config.fish
        # CachyOS fish config defines `function fish_greeting; fastfetch; end`,
        # which auto-runs at every interactive fish start, on top of the
        # HM-managed auto-run above. Override it to silence the duplicate.
        function fish_greeting; end
      end

      fish_add_path --prepend $HOME/.npm-packages/bin $HOME/bin
      fish_add_path --prepend $HOME/.local/bin

      test -r "$HOME/.opam/opam-init/init.fish" && source "$HOME/.opam/opam-init/init.fish" > /dev/null 2> /dev/null; or true

      set -gx EDITOR "micro"
      set -gx VISUAL "zeditor"

      if status is-interactive; and test -t 1; and test "$TERM" != dumb; and not set -q __HM_FASTFETCH_INIT_DONE; and command -q fastfetch
        # Keep this guard shell-local rather than exported. `exec fish` inherits
        # exported variables from the replaced shell, so an exported guard would
        # suppress the rich fastfetch banner after a terminal reload.
        set -g __HM_FASTFETCH_INIT_DONE 1
        fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
        echo
      end
    '';
  };

  zsh = {
    enable = true;
    # Adopt the XDG layout: zsh dotfiles live under ~/.config/zsh/.
    # HM exports $ZDOTDIR for us so zsh reads from there automatically.
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true;
    envExtra = ''
      # Home Manager owns zsh startup; skip global zshrc files before
      # Powerlevel10k instant prompt.
      unsetopt GLOBAL_RCS
    '';
    autocd = false;
    cdpath = [ "~/Projects" ];
    autosuggestion = {
      enable = true;
      strategy = [ "history" "completion" ];
      highlight = "fg=8";
    };
    historySubstringSearch = {
      enable = true;
      searchUpKey = [ "$terminfo[kcuu1]" "^[[A" ];
      searchDownKey = [ "$terminfo[kcud1]" "^[[B" ];
    };
    oh-my-zsh = {
      enable = true;
      theme = "";
      plugins = [
        "git"
        "sudo"
        "aws"
        "direnv"
      ] ++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
        "docker"
        "docker-compose"
      ] ++ [
        "gh"
        "kubectl"
        "terraform"
        "tmux"
      ];
      extraConfig = ''
        DISABLE_AUTO_UPDATE="true"
        DISABLE_UPDATE_PROMPT="true"
        CASE_SENSITIVE="false"
        HYPHEN_INSENSITIVE="true"
        ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh-${pkgs.stdenv.hostPlatform.system}-hm-v2"
        ZSH_COMPDUMP="$HOME/.cache/zsh/.zcompdump-${pkgs.stdenv.hostPlatform.system}-hm-v2-$ZSH_VERSION"
      '';
    };
    plugins = [
      {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
          name = "powerlevel10k-config";
          src = lib.cleanSource ./config;
          file = "p10k.zsh";
      }
    ];
    initContent = lib.mkMerge [
      (lib.mkBefore ''
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

        if [[ -o interactive && -t 1 && "''${TERM:-}" != "dumb" && "''${FASTFETCH_INIT_PID:-}" != "$$" ]] && command -v fastfetch >/dev/null 2>&1; then
          export FASTFETCH_INIT_PID=$$
          fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
          echo
        fi

        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi

        if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
          . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
          . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
        fi

        # Define variables for directories
        export PATH=$HOME/.npm-packages/bin:$HOME/bin:$PATH
        export PATH=$HOME/.local/bin:$PATH

        [[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"
        [[ -f "$HOME/.ghcup/env" ]] && . "$HOME/.ghcup/env"
        [[ -f /usr/share/cachyos-zsh-config/cachyos-config.zsh ]] && source /usr/share/cachyos-zsh-config/cachyos-config.zsh

        # Node comes from fnm (official prebuilt releases) rather than nixpkgs:
        # source-built Node breaks @deepseek-ai/dsh's native require-builtin
        # addon. See modules/shared/packages.nix. One-time: `fnm install 22 &&
        # fnm default 22`; after that `node` resolves to a DSH-compatible build.
        if command -v fnm >/dev/null 2>&1; then
          eval "$(fnm env --use-on-cd --shell zsh)"
        fi

        # OMX/tmux launches source ~/.zshrc from non-interactive shells to recover
        # PATH. Stop here before interactive-only plugin/history/setopt setup.
        if [[ ! -o interactive ]]; then
          return
        fi

        # Start from a deterministic function search path so nested shells do
        # not inherit stale oh-my-zsh plugin completion paths.
        fpath=("${pkgs.zsh}/share/zsh/${pkgs.zsh.version}/functions")

        # Remove history data we don't want to see
        export HISTIGNORE="pwd:ls:cd"

        # Ripgrep alias
        alias search=rg -p --glob '!node_modules/*'  $@

        # micro for the terminal, Zed for GUI launches. The Zed CLI is
        # `zeditor`, not `zed`: nixpkgs' zed-editor ships only that name.
        export EDITOR="micro"
        export VISUAL="zeditor"

        e() {
            micro "$@"
        }

        # nix shortcuts
        shell() {
            nix-shell '<nixpkgs>' -A "$1"
        }

        fastfetch() {
            local arg
            for arg in "$@"; do
                case "$arg" in
                    -c|--config|--config=*) command fastfetch "$@"; return ;;
                esac
            done

            command fastfetch --config "$HOME/.config/fastfetch/config.jsonc" "$@"
        }

        # pnpm is a javascript package manager
        alias pn=pnpm
        alias px=pnpx

        # Use difftastic, syntax-aware diffing
        alias diff=difft

        # Always color ls and group directories
        alias ls='ls --color=auto'
      '')

      (lib.mkOrder 850 ''
        mkdir -p "$HOME/.cache/zsh"
        zmodload zsh/complist

        zstyle ':completion:*' menu select
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        zstyle ':completion:*' special-dirs true
        zstyle ':completion:*' squeeze-slashes true
        zstyle ':completion:*' use-cache on
        zstyle ':completion:*' cache-path "$HOME/.cache/zsh"
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':completion:*:warnings' format 'no matches for: %d'
      '')
    ];
  };

  yazi = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    shellWrapperName = "yy";
  };

  git = {
    enable = true;
    ignores = [ "*.swp" ];
    lfs = {
      enable = true;
    };
    signing = {
      format = "ssh";
      key = "~/.ssh/git_signing_ed25519.pub";
      signByDefault = true;
    };
    settings = {
      user = {
        name = gitName;
        email = gitEmail;
      };
      init.defaultBranch = "main";
      core = {
        editor = "vim";
        autocrlf = "input";
      };
      gpg."ssh".allowedSignersFile = "~/.ssh/allowed_signers";
      pull.rebase = true;
      rebase.autoStash = true;
      credential = {
        "https://github.com".helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
        "https://gist.github.com".helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
    };
  };

  fastfetch = {
    enable = true;
  };

  kitty = {
    enable = true;
    # Keep Kitty aligned with the Sweet terminal palette on every host.
    settings = {
      font_family = "FiraCode Nerd Font Mono";
      font_size = 12.0;
      initial_window_width = "110c";
      initial_window_height = "30c";
      background_opacity = 0.65;
      copy_on_select = "yes";
      cursor_shape = "underline";
      cursor_blink_interval = 0.5;
      cursor = "#ff0000";
      cursor_text_color = "#161925";
      shell = "${pkgs.nushell}/bin/nu --login";
      background = "#161925";
      foreground = "#c3c7d1";
      selection_foreground = "#ffffff";
      selection_background = "#1e92ff";
      color0 = "#697388";
      color1 = "#ed254e";
      color2 = "#71f79f";
      color3 = "#f9dc5c";
      color4 = "#7cb7ff";
      color5 = "#c74ded";
      color6 = "#00c1e4";
      color7 = "#dcdfe4";
      color8 = "#697388";
      color9 = "#ed254e";
      color10 = "#71f79f";
      color11 = "#f9dc5c";
      color12 = "#7cb7ff";
      color13 = "#c74ded";
      color14 = "#00c1e4";
      color15 = "#dcdfe4";
    };
  };

  vim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [ vim-airline vim-airline-themes vim-startify vim-tmux-navigator ];
    settings = { ignorecase = true; };
    extraConfig = ''
      "" General
      set number
      set history=1000
      set nocompatible
      set modelines=0
      set encoding=utf-8
      set scrolloff=3
      set showmode
      set showcmd
      set hidden
      set wildmenu
      set wildmode=list:longest
      set cursorline
      set ttyfast
      set nowrap
      set ruler
      set backspace=indent,eol,start
      set laststatus=2
      set clipboard=autoselect

      " Dir stuff
      set nobackup
      set nowritebackup
      set noswapfile
      set backupdir=~/.config/vim/backups
      set directory=~/.config/vim/swap

      " Relative line numbers for easy movement
      set relativenumber
      set rnu

      "" Whitespace rules
      set tabstop=8
      set shiftwidth=2
      set softtabstop=2
      set expandtab

      "" Searching
      set incsearch
      set gdefault

      "" Statusbar
      set nocompatible " Disable vi-compatibility
      set laststatus=2 " Always show the statusline
      let g:airline_theme='bubblegum'
      let g:airline_powerline_fonts = 1

      "" Local keys and such
      let mapleader=","
      let maplocalleader=" "

      "" Change cursor on mode
      :autocmd InsertEnter * set cul
      :autocmd InsertLeave * set nocul

      "" File-type highlighting and configuration
      syntax on
      filetype on
      filetype plugin on
      filetype indent on

      "" Paste from clipboard
      nnoremap <Leader>, "+gP

      "" Copy from clipboard
      xnoremap <Leader>. "+y

      "" Move cursor by display lines when wrapping
      nnoremap j gj
      nnoremap k gk

      "" Map leader-q to quit out of window
      nnoremap <leader>q :q<cr>

      "" Move around split
      nnoremap <C-h> <C-w>h
      nnoremap <C-j> <C-w>j
      nnoremap <C-k> <C-w>k
      nnoremap <C-l> <C-w>l

      "" Easier to yank entire line
      nnoremap Y y$

      "" Move buffers
      nnoremap <tab> :bnext<cr>
      nnoremap <S-tab> :bprev<cr>

      "" Like a boss, sudo AFTER opening the file to write
      cmap w!! w !sudo tee % >/dev/null

      let g:startify_lists = [
        \ { 'type': 'dir',       'header': ['   Current Directory '. getcwd()] },
        \ { 'type': 'sessions',  'header': ['   Sessions']       },
        \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      }
        \ ]

      let g:startify_bookmarks = [
        \ '~/Projects',
        \ '~/Documents',
        \ ]

      let g:airline_theme='bubblegum'
      let g:airline_powerline_fonts = 1
      '';
     };

  ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux
        "/home/${user}/.ssh/config_external"
      )
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
        "/Users/${user}/.ssh/config_external"
      )
    ];
    settings = {
      "*" = {
        # Set the default values we want to keep
        SendEnv = [ "LANG" "LC_*" ];
        HashKnownHosts = true;
      };
      "github.com" = {
        IdentitiesOnly = true;
        IdentityFile = sshIdentity;
      };
      # The fleet nodes answer to their tailnet names, but a bare MagicDNS
      # label does not resolve through the Nix openssh build on a non-NixOS
      # host: the Nix build cannot use the stub resolver's tailnet search
      # domain, while the distribution's openssh can. Spelling the MagicDNS
      # name out makes `ssh entropy` behave the same on every host in the fleet.
      #
      # Each node also pins the shared Git identity. It is the one key every
      # host holds and the one key every host authorizes for login, so without
      # this a host presents its own machine key and gets a password prompt.
      "entropy" = {
        HostName = "entropy.tailf8e61e.ts.net";
        User = user;
        IdentitiesOnly = true;
        IdentityFile = sshIdentity;
      };
      "remembrance" = {
        HostName = "remembrance.tailf8e61e.ts.net";
        User = user;
        IdentitiesOnly = true;
        IdentityFile = sshIdentity;
      };
      # A tailnet node name is fixed when the machine joins, not derived from
      # its hostname: this laptop answers to nixos-thinkpad while its hostname
      # is massive. Installing NixOS as antagony therefore does not rename the
      # node, so antagony stays a forward reference until the node is renamed
      # in the Tailscale admin console. nixos-thinkpad answers today.
      "antagony" = {
        HostName = "antagony.tailf8e61e.ts.net";
        User = user;
        IdentitiesOnly = true;
        IdentityFile = sshIdentity;
      };
      "nixos-thinkpad" = {
        HostName = "nixos-thinkpad.tailf8e61e.ts.net";
        User = user;
        IdentitiesOnly = true;
        IdentityFile = sshIdentity;
      };
    };
  };

  tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      sensible
      yank
      prefix-highlight
      {
        plugin = power-theme;
        extraConfig = ''
           set -g @tmux_power_theme 'gold'
        '';
      }
      {
        plugin = resurrect; # Used by tmux-continuum

        # Use XDG data directory
        # https://github.com/tmux-plugins/tmux-resurrect/issues/348
        extraConfig = ''
          set -g @resurrect-dir '$HOME/.cache/tmux/resurrect'
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-pane-contents-area 'visible'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5' # minutes
        '';
      }
    ];
    terminal = "screen-256color";
    prefix = "C-x";
    escapeTime = 10;
    historyLimit = 50000;
    extraConfig = ''
      set -g allow-passthrough on

      # Remove Vim mode delays
      set -g focus-events on

      # Enable full mouse support
      set -g mouse on

      # -----------------------------------------------------------------------------
      # Key bindings
      # -----------------------------------------------------------------------------

      # Unbind default keys
      unbind C-b
      unbind '"'
      unbind %

      # Split panes, vertical or horizontal
      bind-key x split-window -v
      bind-key v split-window -h

      # Move around panes with vim-like bindings (h,j,k,l)
      bind-key -n M-k select-pane -U
      bind-key -n M-h select-pane -L
      bind-key -n M-j select-pane -D
      bind-key -n M-l select-pane -R

      # Smart pane switching with awareness of Vim splits.
      # This is copy paste from https://github.com/christoomey/vim-tmux-navigator
      is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
        | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
      bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
      bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
      bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
      bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
      tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
      if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
        "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
      if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
        "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

      bind-key -T copy-mode-vi 'C-h' select-pane -L
      bind-key -T copy-mode-vi 'C-j' select-pane -D
      bind-key -T copy-mode-vi 'C-k' select-pane -U
      bind-key -T copy-mode-vi 'C-l' select-pane -R
      bind-key -T copy-mode-vi 'C-\' select-pane -l
      '';
    };
}
