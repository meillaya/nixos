#!/usr/bin/env bash
# tests/install-staging.sh - staging and transport invariants for the installer.
#
# Static greps over the live repo files, one live `--dry-run`, plus one BEHAVIORAL
# block that actually runs the staging generator and asserts the artifact it
# produces; no cached copies, so the check fails the moment a pinned token is
# removed or the generator stops behaving.
#
# tests/bootstrap-password-lifecycle.sh (bind mounts over /var/lib and
# /etc/shadow) stays a deliberate manual gate, out of `nix flake check`.
# unshare probe verdict (2026-10-06, this host): `unshare -Ur -m` succeeds and a
# bind mount works inside the namespace, so the suite *could* run under a user
# namespace - it is left manual anyway because the plan's Must-NOT rules keep the
# destructive-risk bind-mount harness out of the check suite. Verified with:
#   unshare -Ur -m -- bash -c 'mkdir -p $d/a $d/b; mount --bind $d/a $d/b' => BIND_OK
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

helper=bin/_install-staging.sh
app=apps/x86_64-linux/install
operator=bin/host-install.sh

fail() {
  echo "install-staging: $*" >&2
  exit 1
}

# require <file> <literal> - the file must contain the exact literal text.
require() {
  local file=$1 token=$2
  [[ -f $file ]] || fail "missing file: $file"
  grep -Fq -- "$token" "$file" \
    || fail "$file is missing the pinned token: $token"
}

require "$helper" '--method=yescrypt'
require "$helper" '--stdin'

# The exact regex the activation validator enforces on the staged hash.
hash_regex='^\$y\$[./A-Za-z0-9]+\$[./A-Za-z0-9]{1,86}\$[./A-Za-z0-9]{43}$'
grep -Fq -- "$hash_regex" "$helper" \
  || fail "$helper is missing the yescrypt validator regex"
require "$helper" '_STAGING_HASH_REGEX='

require "$helper" '0700'
require "$helper" '0600'
require "$helper" 'unset pw'

require "$helper" 'var/lib/nixos-bootstrap'
require "$helper" 'var/lib/nixos-enrollment'
require "$helper" 'sops/age/keys.txt'

require "$app" '--extra-files'
require "$operator" '--extra-files'
require "$app" '--chown'
require "$operator" '--chown'
require "$app" '--chown "home/${install_user}/.config"'
require "$app" 'transport+=(--extra-files "$stage")'
require "$operator" 'transport+=(--extra-files "$operator_stage")'
require "$operator" 'transport+=(--chown "$operator_chown_path" "$operator_chown_owner")'

# Count the printf format, not the prose ("a per-install password for the
# target's user" in the usage text would otherwise inflate a naive count).
pw_total=0
for file in "$helper" "$app" "$operator"; do
  count=$(grep -Fc -- 'password for %s: %s' "$file" || true)
  pw_total=$((pw_total + count))
done
[[ $pw_total -eq 1 ]] \
  || fail "expected exactly one 'password for %s: %s' print across the install scripts; found $pw_total"
grep -Fq -- 'password for %s: %s' "$helper" \
  || fail "the single password print must live in $helper"

# Run the dry-run through bash (never exec the file) so the check does not depend
# on the script's shebang resolving inside the sandbox.
plan=$(bash "$app" --dry-run 2>&1) || fail "apps/x86_64-linux/install --dry-run failed"
grep -Fq -- '--extra-files <stage>' <<<"$plan" \
  || fail "--dry-run plan does not print the --extra-files transport step"
grep -Fq 'tmpfs stage' <<<"$plan" \
  || fail "--dry-run plan does not print the staging step"
if grep -Fq 'password for ' <<<"$plan"; then
  fail "--dry-run printed a 'password for' line; the plan must carry no secret"
fi
if grep -Eq '\$y\$' <<<"$plan"; then
  fail "--dry-run printed a yescrypt hash; the plan must carry no secret"
fi

# --- Behavioral: execute the generator and assert its artifact -------------
# The greps above pin the helper's text; this block runs it for real (F2 major
# 3: the generator had token coverage only). `mkpasswd` comes from the check's
# nativeBuildInputs, so the same binary the installer uses is on PATH.
. "$helper"

stageprobe_user=stageprobe

# staging_init must be called directly, never as $(staging_init): its EXIT trap
# would run in the substitution subshell and delete the stage before we use it.
staging_init >/dev/null \
  || fail "staging_init did not find a writable tmpfs stage"
stage=$STAGING_DIR
[[ -n $stage && -d $stage ]] \
  || fail "staging_init did not set STAGING_DIR to a directory"

pw_out=$(staging_password "$stage" "$stageprobe_user") \
  || fail "staging_password failed to hash a password"

# The password is printed exactly once, and the printed line is the only place
# it appears - never on disk.
pw_lines=$(grep -c -- "^password for ${stageprobe_user}: " <<<"$pw_out" || true)
[[ $pw_lines -eq 1 ]] \
  || fail "staging_password must print the password exactly once; saw $pw_lines line(s)"
if grep -Eq '\$y\$' <<<"$pw_out"; then
  fail "staging_password printed the hash; only the plaintext password belongs on stdout"
fi
plaintext_pw=${pw_out#password for ${stageprobe_user}: }
[[ -n $plaintext_pw && $plaintext_pw != "$pw_out" ]] \
  || fail "could not read the plaintext password back from the printed line"

hash_file="$stage/var/lib/nixos-bootstrap/${stageprobe_user}-password.hash"
hash_dir=${hash_file%/*}
[[ -f $hash_file ]] || fail "staging_password did not create $hash_file"
[[ "$(stat -c '%a' -- "$hash_dir")" == 700 ]] \
  || fail "staged hash directory must be 0700; got $(stat -c '%a' -- "$hash_dir")"
[[ "$(stat -c '%a' -- "$hash_file")" == 600 ]] \
  || fail "staged hash file must be 0600; got $(stat -c '%a' -- "$hash_file")"

# The very regex the activation validator enforces, now checked against the
# bytes the generator wrote rather than against its source text.
hash_content=$(<"$hash_file")
grep -Eqx -- "$hash_regex" <<<"$hash_content" \
  || fail "staged hash does not match the bootstrap validator regex: $hash_content"

if grep -rFq -- "$plaintext_pw" "$stage"; then
  fail "the plaintext password leaked onto disk inside the stage"
fi

# The helper's EXIT trap removes the stage when this script exits.
printf '%s\n' 'install-staging: behavioral generator block PASS'

printf '%s\n' 'install-staging=PASS'
