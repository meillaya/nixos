#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
flake="path:$root"
config_root=

init_config_root() {
  if [[ -n "$config_root" ]]; then
    return
  fi

  local target_system=${DENDRITIC_TARGET_SYSTEM:-$(nix eval --impure --raw --expr 'builtins.currentSystem')}
  case "$target_system" in
    x86_64-linux)
      config_root="f.nixosConfigurations.remembrance"
      ;;
    aarch64-darwin)
      config_root="f.darwinConfigurations.entropy"
      ;;
    *)
      printf >&2 'unsupported dendritic shell target system: %s\n' "$target_system"
      exit 1
      ;;
  esac
}

eval_bin() {
  local package=$1
  local bin=$2
  init_config_root
  nix build --impure --no-link --expr \
    "let f = builtins.getFlake \"$flake\"; in $config_root.pkgs.$package" \
    >/dev/null
  nix eval --impure --raw --expr \
    "let f = builtins.getFlake \"$flake\"; in \"\${$config_root.pkgs.$package}/bin/$bin\""
}

resolve_bin() {
  local env_name=$1
  local package=$2
  local bin=$3
  local direct=${!env_name-}

  if [[ -n "$direct" ]]; then
    printf '%s\n' "$direct"
    return
  fi

  eval_bin "$package" "$bin"
}

nu=$(resolve_bin DENDRITIC_NU_BIN nushell nu)
bash_bin=$(resolve_bin DENDRITIC_BASH_BIN bashInteractive bash)
zsh=$(resolve_bin DENDRITIC_ZSH_BIN zsh zsh)
fish=$(resolve_bin DENDRITIC_FISH_BIN fish fish)

test "$("$nu" -c 'print nu-ok')" = nu-ok
test "$("$bash_bin" -c 'printf bash-ok')" = bash-ok
test "$("$zsh" -fc 'printf zsh-ok')" = zsh-ok
test "$("$fish" -c 'printf fish-ok')" = fish-ok

printf '%s\n' 'dendritic-shells=PASS'
