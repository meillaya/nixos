#!/usr/bin/env bash
set -euo pipefail

cache_url=https://noctalia.cachix.org
cache_key='noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4='
managed_begin='# BEGIN setup-noctalia-cachix (managed)'
managed_end='# END setup-noctalia-cachix (managed)'

test_mode=${NOCTALIA_CACHIX_TEST_MODE:-0}
test_activation=${NOCTALIA_CACHIX_TEST_ACTIVATION:-0}
test_systemctl=${NOCTALIA_CACHIX_TEST_SYSTEMCTL:-}
test_nix=${NOCTALIA_CACHIX_TEST_NIX:-}
conf_dir=${NOCTALIA_CACHIX_CONF_DIR:-/etc/nix}
nix_conf="$conf_dir/nix.conf"
custom_conf="$conf_dir/nix.custom.conf"
systemctl_cmd=systemctl
nix_cmd=nix

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

activation_failure() {
  printf 'ERROR: Noctalia cache configuration was written, but daemon activation was not confirmed: %s\n' "$*" >&2
  printf '%s\n' \
    'RECOVERY: fix the reported Nix/systemd error, run `sudo systemctl restart nix-daemon.service`, then rerun `sudo bin/setup-noctalia-cachix.sh`; if the daemon still cannot start, restore a known-good /etc/nix configuration before retrying.' >&2
  exit 1
}

active_setting_count() {
  local file=$1 key=$2
  [[ -f $file ]] || {
    printf '0\n'
    return
  }
  awk -v key="$key" '
    /^[[:space:]]*#/ { next }
    {
      line = $0
      sub(/[[:space:]]*#.*/, "", line)
      if (line ~ "^[[:space:]]*" key "[[:space:]]*=") count++
    }
    END { print count + 0 }
  ' "$file"
}

includes_custom_conf() {
  [[ -f $nix_conf ]] || return 1
  awk -v custom="$custom_conf" '
    {
      line = $0
      sub(/[[:space:]]*#.*/, "", line)
      if (line !~ /^[[:space:]]*!?include[[:space:]]+/) next
      sub(/^[[:space:]]*!?include[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == custom || line == "nix.custom.conf" || line == "./nix.custom.conf") found = 1
    }
    END { exit !found }
  ' "$nix_conf"
}

# Merge the selected settings in one pass. Existing values are retained, repeated
# active definitions are consolidated, and absent definitions get a managed block.
update_file() {
  local file=$1 add_substituter=$2 add_key=$3 tmp
  mkdir -p "$(dirname "$file")"
  [[ -e $file ]] || : >"$file"
  tmp=$(mktemp "${file}.tmp.XXXXXX")

  awk \
    -v add_sub="$add_substituter" \
    -v add_key="$add_key" \
    -v wanted_sub="$cache_url" \
    -v wanted_key="$cache_key" \
    -v begin="$managed_begin" \
    -v end="$managed_end" '
    function setting_key(line, stripped) {
      stripped = line
      sub(/[[:space:]]*#.*/, "", stripped)
      if (stripped ~ /^[[:space:]]*extra-substituters[[:space:]]*=/) return "extra-substituters"
      if (stripped ~ /^[[:space:]]*extra-trusted-public-keys[[:space:]]*=/) return "extra-trusted-public-keys"
      return ""
    }
    function add_words(value, key,    count, words, i, word) {
      sub(/^[^=]*=[[:space:]]*/, "", value)
      sub(/[[:space:]]*#.*/, "", value)
      count = split(value, words, /[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        word = words[i]
        if (word != "" && !seen[key SUBSEP word]++) merged[key] = merged[key] (merged[key] ? " " : "") word
      }
    }
    {
      lines[++n] = $0
      if ($0 == begin) in_managed = 1
      if (!in_managed) {
        key = setting_key($0)
        selected = (key == "extra-substituters" && add_sub) || (key == "extra-trusted-public-keys" && add_key)
        if (selected) {
          indices[key, ++occurrences[key]] = n
          if (occurrences[key] == 1 && index($0, "#")) {
            comments[key] = substr($0, index($0, "#"))
          }
          add_words($0, key)
        }
      }
      if ($0 == end) in_managed = 0
    }
    END {
      if (add_sub) {
        key = "extra-substituters"
        if (!seen[key SUBSEP wanted_sub]++) merged[key] = merged[key] (merged[key] ? " " : "") wanted_sub
      }
      if (add_key) {
        key = "extra-trusted-public-keys"
        if (!seen[key SUBSEP wanted_key]++) merged[key] = merged[key] (merged[key] ? " " : "") wanted_key
      }

      in_managed = 0
      for (i = 1; i <= n; i++) {
        if (lines[i] == begin) { in_managed = 1; continue }
        if (in_managed) {
          if (lines[i] == end) in_managed = 0
          continue
        }
        key = setting_key(lines[i])
        selected = (key == "extra-substituters" && add_sub) || (key == "extra-trusted-public-keys" && add_key)
        if (!selected) {
          print lines[i]
        } else if (i == indices[key, 1]) {
          print key " = " merged[key] (comments[key] ? " " comments[key] : "")
        } else {
          print "# setup-noctalia-cachix: merged duplicate: " lines[i]
        }
      }

      need_block = (add_sub && !occurrences["extra-substituters"]) || (add_key && !occurrences["extra-trusted-public-keys"])
      if (need_block) {
        print begin
        if (add_sub && !occurrences["extra-substituters"]) print "extra-substituters = " wanted_sub
        if (add_key && !occurrences["extra-trusted-public-keys"]) print "extra-trusted-public-keys = " wanted_key
        print end
      }
    }
  ' "$file" >"$tmp"

  if cmp -s "$tmp" "$file"; then
    rm -f "$tmp"
    return
  fi

  chmod --reference="$file" "$tmp" 2>/dev/null || chmod 0644 "$tmp"
  chown --reference="$file" "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$file"
  printf 'Updated %s\n' "$file"
}

verify_files() {
  local files=("$@") file combined
  combined=$(mktemp)
  for file in "${files[@]}"; do
    [[ -f $file ]] && cat "$file" >>"$combined"
  done
  if ! awk -v url="$cache_url" -v key="$cache_key" '
    /^[[:space:]]*#/ { next }
    /^extra-substituters[[:space:]]*=/ && index($0, url) { have_url = 1 }
    /^extra-trusted-public-keys[[:space:]]*=/ && index($0, key) { have_key = 1 }
    END { exit !(have_url && have_key) }
  ' "$combined"; then
    rm -f "$combined"
    die 'written configuration does not contain the required Noctalia cache URL and key'
  fi
  rm -f "$combined"
}

validate_effective_config() {
  local output
  if ! command -v "$nix_cmd" >/dev/null 2>&1; then
    warn 'nix is unavailable; skipped effective-config validation.'
    return 1
  fi
  if ! output=$("$nix_cmd" config show 2>/dev/null); then
    output=$("$nix_cmd" show-config 2>/dev/null) || {
      warn 'nix could not parse/show the effective configuration.'
      return 1
    }
  fi
  if printf '%s\n' "$output" | awk -v url="$cache_url" -v key="$cache_key" '
    /^(extra-)?substituters[[:space:]]*=/ && index($0, url) { have_url = 1 }
    /^(extra-)?trusted-public-keys[[:space:]]*=/ && index($0, key) { have_key = 1 }
    END { exit !(have_url && have_key) }
  '; then
    printf 'Validated Noctalia URL and key in the effective Nix configuration.\n'
    return 0
  fi
  warn 'effective Nix configuration does not expose the Noctalia URL and key.'
  return 1
}

[[ $test_mode == 0 || $test_mode == 1 ]] || die 'NOCTALIA_CACHIX_TEST_MODE must be 0 or 1'
[[ $test_activation == 0 || $test_activation == 1 ]] || die 'NOCTALIA_CACHIX_TEST_ACTIVATION must be 0 or 1'
if [[ $test_mode == 1 ]]; then
  [[ $conf_dir != /etc/nix ]] || die 'test mode requires NOCTALIA_CACHIX_CONF_DIR outside /etc/nix'
  if (( test_activation )); then
    [[ -x $test_systemctl ]] || die 'activation test mode requires an executable NOCTALIA_CACHIX_TEST_SYSTEMCTL stub'
    [[ -x $test_nix ]] || die 'activation test mode requires an executable NOCTALIA_CACHIX_TEST_NIX stub'
    systemctl_cmd=$test_systemctl
    nix_cmd=$test_nix
  fi
else
  (( test_activation == 0 )) || die 'NOCTALIA_CACHIX_TEST_ACTIVATION is only supported in test mode'
  [[ -z $test_systemctl && -z $test_nix ]] || die 'test command overrides are only supported in activation test mode'
  [[ $conf_dir == /etc/nix ]] || die 'NOCTALIA_CACHIX_CONF_DIR is only supported in test mode'
  (( EUID == 0 )) || die 'root privileges are required; rerun this script as root (for example: sudo bin/setup-noctalia-cachix.sh)'
fi

mkdir -p "$conf_dir"
[[ -e $nix_conf ]] || : >"$nix_conf"

if includes_custom_conf; then
  # A setting already defined in nix.conf stays there; otherwise the included
  # Determinate custom file is the daemon-trusted owner.
  main_sub=$(active_setting_count "$nix_conf" extra-substituters)
  main_key=$(active_setting_count "$nix_conf" extra-trusted-public-keys)
  custom_sub=$(active_setting_count "$custom_conf" extra-substituters)
  custom_key=$(active_setting_count "$custom_conf" extra-trusted-public-keys)

  (( main_sub == 0 || custom_sub == 0 )) || die 'extra-substituters is already active in both nix.conf and nix.custom.conf; resolve that ambiguity first'
  (( main_key == 0 || custom_key == 0 )) || die 'extra-trusted-public-keys is already active in both nix.conf and nix.custom.conf; resolve that ambiguity first'

  update_file "$nix_conf" "$((main_sub > 0))" "$((main_key > 0))"
  update_file "$custom_conf" "$((main_sub == 0))" "$((main_key == 0))"
  verify_files "$nix_conf" "$custom_conf"
  printf 'Used Determinate Nix include: %s\n' "$custom_conf"
else
  update_file "$nix_conf" 1 1
  verify_files "$nix_conf"
  printf 'No Determinate custom include found; used daemon config: %s\n' "$nix_conf"
fi

if [[ $test_mode == 1 && $test_activation == 0 ]]; then
  printf 'Test mode: skipped daemon restart and nix effective-config command.\n'
  exit 0
fi

command -v "$systemctl_cmd" >/dev/null 2>&1 || activation_failure 'systemctl is unavailable'
"$systemctl_cmd" cat nix-daemon.service >/dev/null 2>&1 || \
  activation_failure 'the systemd nix-daemon.service unit is unavailable'
"$systemctl_cmd" restart nix-daemon.service || activation_failure 'nix-daemon.service restart failed'
printf 'Restarted nix-daemon.service.\n'

"$systemctl_cmd" is-active --quiet nix-daemon.service || \
  activation_failure 'nix-daemon.service is not active after restart'
printf 'Confirmed nix-daemon.service is active.\n'

validate_effective_config || activation_failure 'post-restart effective configuration does not contain the Noctalia cache URL and key'

if command -v "$nix_cmd" >/dev/null 2>&1 && "$nix_cmd" store ping --store daemon >/dev/null 2>&1; then
  printf 'Validated that the restarted Nix daemon is reachable.\n'
else
  activation_failure 'the restarted Nix daemon is not reachable'
fi
