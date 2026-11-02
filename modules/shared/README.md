# Shared user configuration

The `mei` user aspect owns this directory's shared Home Manager programs, files,
and static configuration on NixOS, Darwin, and standalone Linux. Each platform's
package module separately consumes the shared package list.

```text
config/            Static program configuration and assets
files.nix          Cross-platform Home Manager files
shell/bash.nix     Bash fallback and readline
shell/nushell.nix  Nushell login shell
home-manager.nix   Git, SSH, Vim, tmux, direnv, Yazi, Kitty, and fastfetch
packages.nix       Cross-platform package list
```

Cross-platform user behavior belongs on `modules/aspects/mei.nix`.
Platform-specific behavior belongs in a feature aspect and may use
`provides.to-users` only when the host genuinely selects that payload.
