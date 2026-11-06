#!/usr/bin/env bash
set -euo pipefail

config="${GAME_TRAINER_CONFIG:-$HOME/.config/game-trainer/games.conf}"
game_filter=""
wait_seconds=0
list_only=0
init_only=0
trainer=""
trainer_args=()
is_ce=0

usage() {
  cat >&2 <<'EOF'
Usage: game-trainer [OPTIONS] [TRAINER.exe [ARGS...]]

Launch a Windows trainer or Cheat Engine in the Wine prefix of the active
game. The game may have been started by Steam, Heroic, Hydra, or any other
Wine/Proton launcher. With no TRAINER, use the matching entry from
~/.config/game-trainer/games.conf.

Options:
  --list             List detected games and exit.
  --game PATTERN     Only consider games whose process name matches PATTERN.
  --wait [SECONDS]   Wait for a game before launching (default 300).
  --config PATH      Use a different configuration file.
  --init             Create or repair a writable config and exit.
  -h, --help         Show this help text.

Config example:
  [LOP-Win64-Shipping.exe]
  trainer=/home/mei/Downloads/Lies of P v1.2-v1.8 Plus 25 Trainer.exe

  [SomeGame.exe]
  cheat_engine=/home/mei/Downloads/cheatengine-x86_64.exe
  table=/home/mei/Downloads/SomeGame.CT
EOF
}

while (($#)); do
  case "$1" in
    --list)
      list_only=1
      shift
      ;;
    --game)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      game_filter="$2"
      shift 2
      ;;
    --wait)
      shift
      if [[ ${1:-} =~ ^[0-9]+$ ]]; then
        wait_seconds="$1"
        shift
      else
        wait_seconds=300
      fi
      ;;
    --config)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      config="$2"
      shift 2
      ;;
    --init)
      init_only=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      exit 2
      ;;
    *)
      trainer="$1"
      shift
      trainer_args=("$@")
      break
      ;;
  esac
done

if ((init_only)); then
  mkdir -p "$(dirname "$config")"
  if [[ -e "$config" ]]; then
    chmod u+rw "$config"
  else
    example="$config.example"
    if [[ -f "$example" ]]; then
      cp -- "$example" "$config"
    else
      cat > "$config" <<'EOF'
# Map a game process name to a trainer or Cheat Engine.
#
# [LOP-Win64-Shipping.exe]
# trainer=/home/mei/Downloads/trainer.exe
EOF
    fi
    chmod 600 "$config"
  fi
  printf 'Config: %s\n' "$config"
  exit 0
fi

if [[ -n "$trainer" ]]; then
  [[ -f "$trainer" ]] || { printf 'game-trainer: no such file: %s\n' "$trainer" >&2; exit 1; }
  trainer=$(readlink -f -- "$trainer")
  case "${trainer,,}" in
    *cheat*engine*) is_ce=1 ;;
  esac
fi

find_games() {
  local envfile pid env_dump prefix proton game rss
  for envfile in /proc/[0-9]*/environ; do
    pid=${envfile#/proc/}
    pid=${pid%/environ}
    [[ -r "$envfile" ]] || continue
    env_dump=$( { tr '\0' '\n' < "$envfile"; } 2>/dev/null ) || continue
    prefix=$(printf '%s\n' "$env_dump" | sed -n 's/^WINEPREFIX=//p' | head -n1)
    prefix=${prefix%/}
    [[ -n "$prefix" ]] || continue
    proton=$(printf '%s\n' "$env_dump" | sed -n 's/^PROTONPATH=//p' | head -n1)
    game=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | head -n1)
    game=${game##*/}
    game=${game##*\\}
    [[ -n "$game" ]] || continue
    case "${game,,}" in
      wineserver|wine|wine64|winedevice.exe|services.exe|plugplay.exe|svchost.exe|explorer.exe|rpcss.exe|conhost.exe|cmd.exe|umu.exe|steam.exe|steamwebhelper.exe|xalia.exe|start.exe|rundll32.exe|winemenubuilder.exe|tabtip.exe|lsass.exe|winlogon.exe|csrss.exe|dwm.exe|fontdrvhost.exe|wineboot.exe|winecfg.exe|regsvr32.exe|msiexec.exe)
        continue
        ;;
      *trainer*|*cheat*engine*|*crashmailer*|*crashhandler*|python*|pv-adverb|srt-bwrap|pressure-vessel*|proton|protonfixes*|reaper)
        continue
        ;;
    esac
    rss=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$pid/status" 2>/dev/null || printf '0\n')
    [[ -n "$rss" ]] || rss=0
    printf '%s\t%s\t%s\t%s\t%s\n' "$rss" "$pid" "$prefix" "$proton" "$game"
  done | sort -t $'\t' -k1,1nr
}

focused_pid() {
  command -v niri >/dev/null 2>&1 || return 0
  niri msg focused-window 2>/dev/null | awk '/^  PID:/ { print $2; exit }'
}

select_game() {
  local rss pid prefix proton game line focus
  local -a lines=()
  focus=$(focused_pid || true)
  while :; do
    lines=()
    while IFS=$'\t' read -r rss pid prefix proton game; do
      [[ -n "$game" ]] || continue
      if [[ -n "$game_filter" && "${game,,}" != *"${game_filter,,}"* ]]; then
        continue
      fi
      lines+=("$rss"$'\t'"$pid"$'\t'"$prefix"$'\t'"$proton"$'\t'"$game")
    done < <(find_games)
    if ((${#lines[@]})); then
      for line in "${lines[@]}"; do
        IFS=$'\t' read -r rss pid prefix proton game <<< "$line"
        if [[ -n "$focus" && "$pid" == "$focus" ]]; then
          printf '%s\n' "$line"
          return 0
        fi
      done
      printf '%s\n' "${lines[0]}"
      return 0
    fi
    if ((wait_seconds > 0 && SECONDS < deadline)); then
      sleep 2
      continue
    fi
    return 1
  done
}

if ((list_only)); then
  printf 'PID\tRSS_KB\tGAME\tPREFIX\tPROTONPATH\n'
  while IFS=$'\t' read -r rss pid prefix proton game; do
    [[ -n "$game" ]] || continue
    if [[ -n "$game_filter" && "${game,,}" != *"${game_filter,,}"* ]]; then
      continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$pid" "$rss" "$game" "$prefix" "$proton"
  done < <(find_games)
  exit 0
fi

deadline=$((SECONDS + wait_seconds))
selected=$(select_game) || {
  printf 'game-trainer: no running Wine/Proton game found.\n' >&2
  printf 'Start the game first, or use --wait.\n' >&2
  exit 1
}
IFS=$'\t' read -r rss pid prefix proton game <<< "$selected"

env_dump=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null || true)
sync_args=()
for name in WINEESYNC WINEFSYNC WINEFSUNC WINEUNIXSYNC; do
  value=$(printf '%s\n' "$env_dump" | sed -n "s/^$name=//p" | head -n1)
  [[ -n "$value" ]] && sync_args+=("$name=$value")
done

find_wine_from_prefix() {
  local prefix="$1" candidate envfile
  for candidate in /proc/[0-9]*; do
    [[ -r "$candidate/cmdline" ]] || continue
    [[ "$(tr '\0' '\n' < "$candidate/cmdline" 2>/dev/null | head -n1 | xargs -r basename)" == "wineserver" ]] || continue
    envfile="$candidate/environ"
    [[ -r "$envfile" ]] || continue
    if tr '\0' '\n' < "$envfile" 2>/dev/null | grep -Fxq "WINEPREFIX=$prefix"; then
      local exe
      exe=$(readlink -f "$candidate/exe" 2>/dev/null || true)
      [[ -n "$exe" ]] || continue
      printf '%s\n' "$(dirname "$exe")"
      return 0
    fi
  done
  return 1
}

if [[ -z "$proton" ]]; then
  bin_dir=$(find_wine_from_prefix "$prefix" || true)
else
  bin_dir="$proton/files/bin"
fi
[[ -n "$bin_dir" ]] || { printf 'game-trainer: cannot find the Proton Wine directory for %s\n' "$game" >&2; exit 1; }

desc=$(file -b -- "$trainer" 2>/dev/null || true)
case "$desc" in
  *PE32+*|*x86-64*)
    wine_name=wine64
    ;;
  *PE32*|*80386*|*i386*)
    wine_name=wine
    ;;
  *)
    wine_name=wine64
    ;;
esac
wine="$bin_dir/$wine_name"
if [[ ! -x "$wine" ]]; then
  for fallback in wine64 wine; do
    if [[ -x "$bin_dir/$fallback" ]]; then
      wine="$bin_dir/$fallback"
      break
    fi
  done
fi
[[ -x "$wine" ]] || { printf 'game-trainer: no Wine binary under %s\n' "$bin_dir" >&2; exit 1; }

if [[ -z "$trainer" ]]; then
  if [[ ! -f "$config" ]]; then
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "Game Trainer" "No trainer configured for $game. Create $config." || true
    fi
    printf 'game-trainer: no trainer configured for %s; create %s\n' "$game" "$config" >&2
    exit 1
  fi

  section=""
  found_trainer=""
  found_ce=""
  found_table=""
  while IFS= read -r line; do
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == \[*\] ]]; then
      section=${line#\[}
      section=${section%\]}
      continue
    fi
    [[ "$section" == "$game" && "$line" == *=* ]] || continue
    key=${line%%=*}
    value=${line#*=}
    key=${key%"${key##*[![:space:]]}"}
    value=${value#"${value%%[![:space:]]*}"}
    case "$key" in
      trainer) found_trainer="$value" ;;
      cheat_engine) found_ce="$value" ;;
      table) found_table="$value" ;;
    esac
  done < "$config"

  if [[ -n "$found_trainer" ]]; then
    trainer="$found_trainer"
  elif [[ -n "$found_ce" ]]; then
    trainer="$found_ce"
    is_ce=1
    [[ -n "$found_table" ]] && trainer_args=("$found_table")
  fi

  if [[ -z "$trainer" ]]; then
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "Game Trainer" "No trainer configured for $game. Edit $config." || true
    fi
    printf 'game-trainer: no trainer configured for %s in %s\n' "$game" "$config" >&2
    exit 1
  fi
  [[ -f "$trainer" ]] || { printf 'game-trainer: no such file: %s\n' "$trainer" >&2; exit 1; }
  trainer=$(readlink -f -- "$trainer")
fi

printf 'Game:    %s (PID %s)\n' "$game" "$pid" >&2
printf 'Prefix:  %s\n' "$prefix" >&2
printf 'Trainer: %s\n' "$trainer" >&2

if ((is_ce)); then
  ce_dir="$(dirname "$trainer")"
  if [[ ! -w "$ce_dir" ]]; then
    cache="$HOME/.local/share/game-trainer/ce-$(basename "$(dirname "$(dirname "$ce_dir")")")"
    if [[ ! -x "$cache/$(basename "$trainer")" ]]; then
      mkdir -p "$cache"
      cp -a "$ce_dir/." "$cache/"
      chmod -R u+w "$cache"
    fi
    trainer="$cache/$(basename "$trainer")"
    ce_dir="$cache"
  fi

  autorun="$ce_dir/autorun"
  if install -d "$autorun" 2>/dev/null; then
    cat > "$autorun/game-trainer-attach.lua" <<'EOF'
local game = os.getenv("GAME_TRAINER_GAME")
if game and game ~= "" then
  local pid = getProcessIDFromProcessName(game)
  if pid then openProcess(pid) end
end
EOF
  fi
fi

case "$(file -b -- "$trainer" 2>/dev/null || true)" in
  *ELF*)
    if ((is_ce)); then
      cd -- "$(dirname "$trainer")"
      exec env GAME_TRAINER_GAME="$game" GAME_TRAINER_PID="$pid" "$trainer" "${trainer_args[@]}"
    fi
    ;;
esac

exec env WINEPREFIX="$prefix" WINEDEBUG=-all "${sync_args[@]}" GAME_TRAINER_GAME="$game" GAME_TRAINER_PID="$pid" "$wine" "$trainer" "${trainer_args[@]}"
