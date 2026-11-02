{ config, pkgs, lib, ... }:

let
    user = config.home.username or "mei";
    gitName = "Meillaya";
    gitEmail = "nathanagbomed@proton.me";

    # The identity home-manager installs on every host at ~/.ssh/id_github, and
    # at ~/.ssh/id_ed25519 when that path is free. Offering it to the fleet is
    # what makes host-to-host SSH work: every host authorizes this key for
    # login, and no host holds the older installer anchor it replaced.
    sshDir = "${config.home.homeDirectory}/.ssh";
    sshIdentity = [
      "${sshDir}/id_github"
      "${sshDir}/id_ed25519"
    ];
in
(import ./shell/bash.nix { inherit pkgs lib; }) // {
  direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableNushellIntegration = true;
    enableBashIntegration = true;
  };

  yazi = {
    enable = true;
    enableBashIntegration = true;
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
    includes = [ "${sshDir}/config_external" ];
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
