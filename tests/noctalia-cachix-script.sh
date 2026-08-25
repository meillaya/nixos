#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/bin/setup-noctalia-cachix.sh"
cache_url=https://noctalia.cachix.org
cache_key='noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4='
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

run_script() {
  NOCTALIA_CACHIX_TEST_MODE=1 NOCTALIA_CACHIX_CONF_DIR="$1" bash "$script"
}

mock_dir="$tmp_root/mock-commands"
mock_log="$tmp_root/mock-commands.log"
mkdir -p "$mock_dir"

cat >"$mock_dir/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl %s\n' "$*" >>"${MOCK_LOG:?}"
case ${1:-} in
  cat)
    [[ ${MOCK_SYSTEMCTL_UNIT:-present} == present ]]
    ;;
  restart)
    [[ ${MOCK_SYSTEMCTL_RESTART:-success} == success ]]
    ;;
  is-active)
    [[ ${MOCK_SYSTEMCTL_ACTIVE:-success} == success ]]
    ;;
  *)
    exit 64
    ;;
esac
EOF

cat >"$mock_dir/nix" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'nix %s\\n' "\$*" >>"\${MOCK_LOG:?}"
if [[ \${1:-} == config && \${2:-} == show ]] || [[ \${1:-} == show-config ]]; then
  case \${MOCK_NIX_CONFIG:-success} in
    success)
      printf '%s\\n' 'extra-substituters = $cache_url' 'extra-trusted-public-keys = $cache_key'
      ;;
    missing)
      printf '%s\\n' 'substituters = https://cache.nixos.org'
      ;;
    fail)
      exit 1
      ;;
  esac
elif [[ \${1:-} == store && \${2:-} == ping ]]; then
  [[ \${MOCK_NIX_PING:-success} == success ]]
else
  exit 64
fi
EOF
chmod +x "$mock_dir/systemctl" "$mock_dir/nix"

run_activation_script() {
  local conf_dir=$1
  local unit_state=${2:-present}
  local restart_state=${3:-success}
  local active_state=${4:-success}
  local config_state=${5:-success}
  local ping_state=${6:-success}

  env \
    NOCTALIA_CACHIX_TEST_MODE=1 \
    NOCTALIA_CACHIX_TEST_ACTIVATION=1 \
    NOCTALIA_CACHIX_TEST_SYSTEMCTL="$mock_dir/systemctl" \
    NOCTALIA_CACHIX_TEST_NIX="$mock_dir/nix" \
    NOCTALIA_CACHIX_CONF_DIR="$conf_dir" \
    MOCK_LOG="$mock_log" \
    MOCK_SYSTEMCTL_UNIT="$unit_state" \
    MOCK_SYSTEMCTL_RESTART="$restart_state" \
    MOCK_SYSTEMCTL_ACTIVE="$active_state" \
    MOCK_NIX_CONFIG="$config_state" \
    MOCK_NIX_PING="$ping_state" \
    bash "$script"
}

active_count() {
  local key=$1 file=$2
  awk -v key="$key" '$0 !~ /^[[:space:]]*#/ && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" { count++ } END { print count + 0 }' "$file"
}

assert_contains() {
  grep -Fq -- "$1" "$2" || fail "$2 does not contain: $1"
}

assert_not_contains() {
  if grep -Fq -- "$1" "$2"; then
    fail "$2 unexpectedly contains: $1"
  fi
}

# Determinate include: preserve unrelated content, merge an existing setting,
# put the missing key in nix.custom.conf, and remain byte-for-byte idempotent.
case1="$tmp_root/determinate"
mkdir -p "$case1"
cat >"$case1/nix.conf" <<'EOF'
experimental-features = nix-command flakes
!include nix.custom.conf
trusted-users = root mei
EOF
cat >"$case1/nix.custom.conf" <<'EOF'
# Existing local cache must survive.
extra-substituters = https://cache.example.test # keep this cache
max-jobs = auto
EOF
run_script "$case1"
assert_contains 'trusted-users = root mei' "$case1/nix.conf"
assert_contains 'extra-substituters = https://cache.example.test https://noctalia.cachix.org # keep this cache' "$case1/nix.custom.conf"
assert_contains "extra-trusted-public-keys = $cache_key" "$case1/nix.custom.conf"
[[ $(active_count extra-substituters "$case1/nix.custom.conf") == 1 ]] || fail 'duplicate substituter setting after Determinate update'
before=$(sha256sum "$case1/nix.conf" "$case1/nix.custom.conf")
run_script "$case1"
after=$(sha256sum "$case1/nix.conf" "$case1/nix.custom.conf")
[[ $before == "$after" ]] || fail 'Determinate update is not idempotent'

# Fallback: update nix.conf without creating an unused custom file, consolidate
# repeated active definitions, and preserve all values.
case2="$tmp_root/fallback"
mkdir -p "$case2"
cat >"$case2/nix.conf" <<'EOF'
sandbox = true
extra-trusted-public-keys = cache.example.test-1:abc=
extra-trusted-public-keys = cache.other.test-1:def=
EOF
run_script "$case2"
[[ ! -e $case2/nix.custom.conf ]] || fail 'fallback unexpectedly created nix.custom.conf'
assert_contains 'sandbox = true' "$case2/nix.conf"
assert_contains "$cache_url" "$case2/nix.conf"
assert_contains "extra-trusted-public-keys = cache.example.test-1:abc= cache.other.test-1:def= $cache_key" "$case2/nix.conf"
[[ $(active_count extra-trusted-public-keys "$case2/nix.conf") == 1 ]] || fail 'duplicate key setting was not consolidated'
before=$(sha256sum "$case2/nix.conf")
run_script "$case2"
after=$(sha256sum "$case2/nix.conf")
[[ $before == "$after" ]] || fail 'fallback update is not idempotent'

# If nix.conf already owns one setting, keep it there and put only the missing
# setting in the Determinate include; do not create a cross-file duplicate.
case3="$tmp_root/split-owner"
mkdir -p "$case3"
cat >"$case3/nix.conf" <<'EOF'
extra-substituters = https://cache.example.test
!include nix.custom.conf
EOF
printf '%s\n' 'connect-timeout = 10' >"$case3/nix.custom.conf"
run_script "$case3"
assert_contains "extra-substituters = https://cache.example.test $cache_url" "$case3/nix.conf"
assert_contains "extra-trusted-public-keys = $cache_key" "$case3/nix.custom.conf"
[[ $(active_count extra-substituters "$case3/nix.custom.conf") == 0 ]] || fail 'split-owner update introduced a cross-file duplicate'

# Refuse an already ambiguous cross-file duplicate rather than add another
# override or silently choose an effective value.
case4="$tmp_root/ambiguous"
mkdir -p "$case4"
cat >"$case4/nix.conf" <<'EOF'
extra-substituters = https://one.example.test
!include nix.custom.conf
EOF
cat >"$case4/nix.custom.conf" <<'EOF'
extra-substituters = https://two.example.test
EOF
before=$(sha256sum "$case4/nix.conf" "$case4/nix.custom.conf")
if run_script "$case4" >"$case4/output" 2>&1; then
  fail 'ambiguous cross-file duplicate unexpectedly succeeded'
fi
after=$(sha256sum "$case4/nix.conf" "$case4/nix.custom.conf")
[[ $before == "$after" ]] || fail 'ambiguous configuration was modified before failure'
assert_contains 'already active in both' "$case4/output"

# Activation simulation cannot accidentally fall through to host commands: test
# mode refuses to proceed unless both command stubs are explicit executables.
case5_guard="$tmp_root/activation-stub-guard"
mkdir -p "$case5_guard"
if env \
  -u NOCTALIA_CACHIX_TEST_SYSTEMCTL \
  -u NOCTALIA_CACHIX_TEST_NIX \
  NOCTALIA_CACHIX_TEST_MODE=1 \
  NOCTALIA_CACHIX_TEST_ACTIVATION=1 \
  NOCTALIA_CACHIX_CONF_DIR="$case5_guard" \
  bash "$script" >"$case5_guard/output" 2>&1; then
  fail 'activation test mode unexpectedly ran without explicit command stubs'
fi
assert_contains 'activation test mode requires an executable NOCTALIA_CACHIX_TEST_SYSTEMCTL stub' "$case5_guard/output"
[[ ! -e $case5_guard/nix.conf ]] || fail 'activation stub guard wrote configuration before rejecting unsafe test commands'

# The production activation path is exercised only through explicit executable
# stubs. A confirmed systemd restart, active service, effective config, and
# daemon ping are all required for success.
case5="$tmp_root/activation-success"
mkdir -p "$case5"
cat >"$case5/nix.conf" <<'EOF'
!include nix.custom.conf
EOF
: >"$case5/nix.custom.conf"
: >"$mock_log"
run_activation_script "$case5" >"$case5/output" 2>&1 || fail 'fully confirmed activation did not succeed'
assert_contains 'Restarted nix-daemon.service.' "$case5/output"
assert_contains 'Confirmed nix-daemon.service is active.' "$case5/output"
assert_contains 'Validated Noctalia URL and key in the effective Nix configuration.' "$case5/output"
assert_contains 'Validated that the restarted Nix daemon is reachable.' "$case5/output"
assert_contains 'systemctl cat nix-daemon.service' "$mock_log"
assert_contains 'systemctl restart nix-daemon.service' "$mock_log"
assert_contains 'systemctl is-active --quiet nix-daemon.service' "$mock_log"
assert_contains 'nix config show' "$mock_log"
assert_contains 'nix store ping --store daemon' "$mock_log"

# A restart failure must leave the trusted file visible for recovery but return
# nonzero, give an explicit recovery instruction, and stop before validation.
case6="$tmp_root/restart-failed"
mkdir -p "$case6"
: >"$mock_log"
if run_activation_script "$case6" present fail >"$case6/output" 2>&1; then
  fail 'failed daemon restart unexpectedly succeeded'
fi
assert_contains "$cache_url" "$case6/nix.conf"
assert_contains 'daemon activation was not confirmed: nix-daemon.service restart failed' "$case6/output"
assert_contains 'RECOVERY: fix the reported Nix/systemd error' "$case6/output"
assert_not_contains 'nix config show' "$mock_log"

# An unavailable systemd unit and an inactive post-restart service are both
# fail-closed outcomes, not warning-only successes.
case7="$tmp_root/unit-unavailable"
mkdir -p "$case7"
: >"$mock_log"
if run_activation_script "$case7" missing >"$case7/output" 2>&1; then
  fail 'unavailable nix-daemon.service unexpectedly succeeded'
fi
assert_contains 'the systemd nix-daemon.service unit is unavailable' "$case7/output"
assert_contains 'RECOVERY:' "$case7/output"

case8="$tmp_root/service-inactive"
mkdir -p "$case8"
: >"$mock_log"
if run_activation_script "$case8" present success fail >"$case8/output" 2>&1; then
  fail 'inactive post-restart daemon unexpectedly succeeded'
fi
assert_contains 'nix-daemon.service is not active after restart' "$case8/output"
assert_contains 'RECOVERY:' "$case8/output"
assert_not_contains 'nix config show' "$mock_log"

# Even with a confirmed active service, missing effective settings or an
# unreachable daemon must fail and prescribe recovery.
case9="$tmp_root/effective-config-missing"
mkdir -p "$case9"
: >"$mock_log"
if run_activation_script "$case9" present success success missing >"$case9/output" 2>&1; then
  fail 'missing effective cache configuration unexpectedly succeeded'
fi
assert_contains 'post-restart effective configuration does not contain the Noctalia cache URL and key' "$case9/output"
assert_contains 'RECOVERY:' "$case9/output"
assert_not_contains 'nix store ping --store daemon' "$mock_log"

case10="$tmp_root/daemon-unreachable"
mkdir -p "$case10"
: >"$mock_log"
if run_activation_script "$case10" present success success success fail >"$case10/output" 2>&1; then
  fail 'unreachable restarted daemon unexpectedly succeeded'
fi
assert_contains 'the restarted Nix daemon is not reachable' "$case10/output"
assert_contains 'RECOVERY:' "$case10/output"

printf 'PASS: Noctalia Cachix setup script regression tests\n'
