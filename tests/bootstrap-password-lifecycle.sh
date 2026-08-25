#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d -t nix-bootstrap-password-lifecycle.XXXXXX)
trap 'rm -rf "$tmp"' EXIT

config="let f = builtins.getFlake (toString $repo); in f.nixosConfigurations.remembrance.config"
nix eval --raw --impure --expr \
  "$config.system.activationScripts.bootstrapPasswordHash.text" \
  > "$tmp/validator.sh"
nix eval --raw --impure --expr \
  "$config.system.activationScripts.consumeBootstrapPassword.text" \
  > "$tmp/consumer.sh"

cat > "$tmp/run-validator.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mount --bind "$1" /var/lib
mount --bind "$2" /etc/shadow
bash "$3"
EOF
cat > "$tmp/run-validator-empty-nss.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mount --bind "$1" /var/lib
mount --bind "$2" /etc/shadow
mount --bind "$3" /etc/passwd
mount --bind "$4" /etc/group
mount --bind "$5" /etc/nsswitch.conf
bash "$6"
EOF
cat > "$tmp/run-consumer.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mount --bind "$1" /var/lib
mount --bind "$2" /etc/shadow
bash "$3"
bash "$4"
EOF

valid="\$y\$j9T\$abcdefghijklmnop\$0123456789012345678901234567890123456789012"
other_valid="\$y\$j9T\$qrstuvwxyzabcdef\$1234567890123456789012345678901234567890123"
empty_salt="\$y\$j9T\$\$0123456789012345678901234567890123456789012"

run_case() {
  local name=$1 expected=$2 root=$3 shadow=$4 expected_output=${5:-}
  local output rc verdict=FAIL
  set +e
  output=$(unshare -Ur -m bash "$tmp/run-validator.sh" \
    "$root" "$shadow" "$tmp/validator.sh" 2>&1)
  rc=$?
  set -e

  if { { [[ $expected == pass && $rc -eq 0 ]]; } \
      || { [[ $expected == fail && $rc -ne 0 ]]; }; } \
    && { [[ $expected != pass ]] || [[ -z $output ]]; } \
    && { [[ -z $expected_output ]] || [[ $output == *"$expected_output"* ]]; }; then
    verdict=PASS
  fi
  printf '%s expected=%s rc=%s verdict=%s output=%q\n' \
    "$name" "$expected" "$rc" "$verdict" "$output"
  [[ $verdict == PASS ]]
}

run_empty_nss_case() {
  local name=$1 expected=$2 root=$3 shadow=$4 expected_output=${5:-}
  local output rc verdict=FAIL
  set +e
  output=$(unshare -Ur -m bash "$tmp/run-validator-empty-nss.sh" \
    "$root" "$shadow" "$tmp/empty-passwd" "$tmp/empty-group" \
    "$tmp/files-only-nsswitch.conf" "$tmp/validator.sh" 2>&1)
  rc=$?
  set -e

  if { { [[ $expected == pass && $rc -eq 0 ]]; } \
      || { [[ $expected == fail && $rc -ne 0 ]]; }; } \
    && { [[ $expected != pass ]] || [[ -z $output ]]; } \
    && { [[ -z $expected_output ]] || [[ $output == *"$expected_output"* ]]; }; then
    verdict=PASS
  fi
  printf '%s expected=%s rc=%s verdict=%s output=%q\n' \
    "$name" "$expected" "$rc" "$verdict" "$output"
  [[ $verdict == PASS ]]
}

mkdir -p "$tmp/valid/nixos-bootstrap"
printf '%s\n' "$valid" > "$tmp/valid/nixos-bootstrap/mei-password.hash"
chmod 600 "$tmp/valid/nixos-bootstrap/mei-password.hash"

mkdir -p "$tmp/sentinel/nixos-bootstrap"
printf '!\n' > "$tmp/sentinel/nixos-bootstrap/mei-password.hash"
chmod 600 "$tmp/sentinel/nixos-bootstrap/mei-password.hash"

mkdir -p "$tmp/missing/nixos-bootstrap"
mkdir -p "$tmp/empty/nixos-bootstrap"
: > "$tmp/empty/nixos-bootstrap/mei-password.hash"
chmod 600 "$tmp/empty/nixos-bootstrap/mei-password.hash"

mkdir -p "$tmp/multiline/nixos-bootstrap"
printf '%s\n%s\n' "$valid" "$valid" \
  > "$tmp/multiline/nixos-bootstrap/mei-password.hash"
chmod 600 "$tmp/multiline/nixos-bootstrap/mei-password.hash"

mkdir -p "$tmp/unterminated-second/nixos-bootstrap"
printf '%s\nextra' "$valid" \
  > "$tmp/unterminated-second/nixos-bootstrap/mei-password.hash"
chmod 600 "$tmp/unterminated-second/nixos-bootstrap/mei-password.hash"

mkdir -p "$tmp/no-final-newline/nixos-bootstrap"
printf '%s' "$valid" > "$tmp/no-final-newline/nixos-bootstrap/mei-password.hash"
chmod 600 "$tmp/no-final-newline/nixos-bootstrap/mei-password.hash"

mkdir -p "$tmp/malformed/nixos-bootstrap"
printf 'not-a-hash\n' > "$tmp/malformed/nixos-bootstrap/mei-password.hash"
chmod 600 "$tmp/malformed/nixos-bootstrap/mei-password.hash"

mkdir -p "$tmp/wrong-mode/nixos-bootstrap"
printf '%s\n' "$valid" > "$tmp/wrong-mode/nixos-bootstrap/mei-password.hash"
chmod 644 "$tmp/wrong-mode/nixos-bootstrap/mei-password.hash"

mkdir -p "$tmp/wrong-parent/nixos-bootstrap"
printf '%s\n' "$valid" > "$tmp/wrong-parent/nixos-bootstrap/mei-password.hash"
chmod 600 "$tmp/wrong-parent/nixos-bootstrap/mei-password.hash"
chmod 777 "$tmp/wrong-parent/nixos-bootstrap"

mkdir -p "$tmp/empty-salt/nixos-bootstrap"
printf '%s\n' "$empty_salt" > "$tmp/empty-salt/nixos-bootstrap/mei-password.hash"
chmod 600 "$tmp/empty-salt/nixos-bootstrap/mei-password.hash"

yescrypt_prefix="\$y\$j9T\$"
dollar="\$"
for boundary in 1 86 87; do
  mkdir -p "$tmp/salt-$boundary/nixos-bootstrap"
  printf -v salt '%*s' "$boundary" ''
  salt=${salt// /a}
  printf '%s%s%s%s\n' "$yescrypt_prefix" "$salt" "$dollar" \
    '0123456789012345678901234567890123456789012' \
    > "$tmp/salt-$boundary/nixos-bootstrap/mei-password.hash"
  chmod 600 "$tmp/salt-$boundary/nixos-bootstrap/mei-password.hash"
done

mkdir -p "$tmp/file-symlink/nixos-bootstrap" "$tmp/file-symlink-target"
printf '%s\n' "$valid" > "$tmp/file-symlink-target/hash"
chmod 600 "$tmp/file-symlink-target/hash"
ln -s "$tmp/file-symlink-target/hash" \
  "$tmp/file-symlink/nixos-bootstrap/mei-password.hash"

mkdir -p "$tmp/file-dangling-symlink/nixos-bootstrap"
ln -s "$tmp/does-not-exist" \
  "$tmp/file-dangling-symlink/nixos-bootstrap/mei-password.hash"

mkdir -p "$tmp/parent-symlink" "$tmp/parent-symlink-target"
chmod 700 "$tmp/parent-symlink-target"
printf '%s\n' "$valid" > "$tmp/parent-symlink-target/mei-password.hash"
chmod 600 "$tmp/parent-symlink-target/mei-password.hash"
ln -s "$tmp/parent-symlink-target" "$tmp/parent-symlink/nixos-bootstrap"

mkdir -p "$tmp/parent-dangling-symlink"
ln -s "$tmp/no-parent-target" "$tmp/parent-dangling-symlink/nixos-bootstrap"

mkdir -p "$tmp/missing-existing"
mkdir -p "$tmp/missing-existing-empty-nss"
mkdir -p "$tmp/consumer-mismatch/nixos-bootstrap"
printf '%s\n' "$valid" > "$tmp/consumer-mismatch/nixos-bootstrap/mei-password.hash"
chmod 600 "$tmp/consumer-mismatch/nixos-bootstrap/mei-password.hash"

find "$tmp" -mindepth 2 -maxdepth 2 -type d -name nixos-bootstrap \
  ! -path "$tmp/wrong-parent/nixos-bootstrap" -exec chmod 700 {} +

printf 'root:*:1:0:99999:7:::\n' > "$tmp/shadow-fresh"
printf 'root:*:1:0:99999:7:::\nmei:%s:1:0:99999:7:::\n' "$valid" \
  > "$tmp/shadow-unlocked"
printf 'root:*:1:0:99999:7:::\nmei:%s:1:0:99999:7:::\n' "$other_valid" \
  > "$tmp/shadow-other-unlocked"
printf 'root:*:1:0:99999:7:::\nmei:!:1:0:99999:7:::\n' > "$tmp/shadow-locked"
: > "$tmp/empty-passwd"
: > "$tmp/empty-group"
printf 'passwd: files\ngroup: files\nshadow: files\n' \
  > "$tmp/files-only-nsswitch.conf"

run_case valid pass "$tmp/valid" "$tmp/shadow-fresh"
run_empty_nss_case valid-empty-target-nss pass \
  "$tmp/valid" "$tmp/shadow-fresh"
run_case sentinel-existing-unlocked pass "$tmp/sentinel" "$tmp/shadow-unlocked"
run_case sentinel-fresh fail "$tmp/sentinel" "$tmp/shadow-fresh"
run_case sentinel-locked fail "$tmp/sentinel" "$tmp/shadow-locked"
run_case missing-existing-unlocked pass "$tmp/missing-existing" "$tmp/shadow-unlocked"
printf '!\n' > "$tmp/expected-migrated-sentinel"
cmp "$tmp/expected-migrated-sentinel" \
  "$tmp/missing-existing/nixos-bootstrap/mei-password.hash"
[[ $(stat -c %a "$tmp/missing-existing/nixos-bootstrap") == 700 ]]
[[ $(stat -c %a "$tmp/missing-existing/nixos-bootstrap/mei-password.hash") == 600 ]]
printf 'missing-existing-unlocked-migrated=PASS\n'
run_empty_nss_case missing-existing-unlocked-empty-target-nss pass \
  "$tmp/missing-existing-empty-nss" "$tmp/shadow-unlocked"
cmp "$tmp/expected-migrated-sentinel" \
  "$tmp/missing-existing-empty-nss/nixos-bootstrap/mei-password.hash"
[[ $(stat -c %a "$tmp/missing-existing-empty-nss/nixos-bootstrap") == 700 ]]
[[ $(stat -c %a "$tmp/missing-existing-empty-nss/nixos-bootstrap/mei-password.hash") == 600 ]]
printf 'missing-existing-unlocked-empty-target-nss-migrated=PASS\n'
run_case missing fail "$tmp/missing" "$tmp/shadow-fresh"
run_case missing-locked fail "$tmp/missing" "$tmp/shadow-locked"
run_case empty fail "$tmp/empty" "$tmp/shadow-fresh"
run_case multiline fail "$tmp/multiline" "$tmp/shadow-fresh"
run_case unterminated-second fail "$tmp/unterminated-second" "$tmp/shadow-fresh"
run_case no-final-newline fail "$tmp/no-final-newline" "$tmp/shadow-fresh"
run_case malformed fail "$tmp/malformed" "$tmp/shadow-fresh"
run_case wrong-mode fail "$tmp/wrong-mode" "$tmp/shadow-fresh"
run_case wrong-parent fail "$tmp/wrong-parent" "$tmp/shadow-fresh"
run_case empty-salt fail "$tmp/empty-salt" "$tmp/shadow-fresh"
run_case salt-1 pass "$tmp/salt-1" "$tmp/shadow-fresh"
run_case salt-86 pass "$tmp/salt-86" "$tmp/shadow-fresh"
run_case salt-87 fail "$tmp/salt-87" "$tmp/shadow-fresh"
run_case file-symlink fail "$tmp/file-symlink" "$tmp/shadow-fresh"
run_case file-dangling-symlink fail \
  "$tmp/file-dangling-symlink" "$tmp/shadow-unlocked"
run_case parent-symlink fail "$tmp/parent-symlink" "$tmp/shadow-fresh" \
  'expected a real directory'
run_case parent-dangling-symlink fail \
  "$tmp/parent-dangling-symlink" "$tmp/shadow-unlocked"

set +e
unshare -Ur -m bash "$tmp/run-consumer.sh" \
  "$tmp/consumer-mismatch" "$tmp/shadow-other-unlocked" \
  "$tmp/validator.sh" "$tmp/consumer.sh"
rc=$?
set -e
if [[ $rc -eq 0 ]]; then
  printf 'consumer mismatch was accepted\n' >&2
  exit 1
fi
printf '%s\n' "$valid" > "$tmp/expected-preserved-hash"
cmp "$tmp/expected-preserved-hash" \
  "$tmp/consumer-mismatch/nixos-bootstrap/mei-password.hash"
printf 'consumer-mismatch-preserves-verifier=PASS rc=%s\n' "$rc"

unshare -Ur -m bash "$tmp/run-consumer.sh" \
  "$tmp/valid" "$tmp/shadow-unlocked" "$tmp/validator.sh" "$tmp/consumer.sh"

printf '!\n' > "$tmp/expected-sentinel"
if ! cmp "$tmp/expected-sentinel" \
  "$tmp/valid/nixos-bootstrap/mei-password.hash"; then
  printf 'consumer sentinel bytes mismatch\n' >&2
  exit 1
fi
unshare -Ur -m bash "$tmp/run-validator.sh" \
  "$tmp/valid" "$tmp/shadow-unlocked" "$tmp/validator.sh"
[[ $(stat -c %a "$tmp/valid/nixos-bootstrap/mei-password.hash") == 600 ]]
printf 'consumer-exact-sentinel-and-revalidation=PASS\n'

printf 'cleanup=%s\n' "$tmp"
