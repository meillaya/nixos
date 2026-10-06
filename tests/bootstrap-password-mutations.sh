#!/usr/bin/env bash
# Mutation coverage for modules/nixos/bootstrap-password.nix: the consumer of
# the (otherwise orphaned) tests/bootstrap-password-config-eval.nix. nix-eval
# only and self-copying, so it carries no bind mounts and is sandbox-safe; the
# bind-mounting tests/bootstrap-password-lifecycle.sh stays a manual gate.
set -euo pipefail

repo=${BOOTSTRAP_MUTATIONS_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
tmp=$(mktemp -d -t nix-bootstrap-mutations.XXXXXX)
trap 'rm -rf "$tmp"' EXIT

config_expr() {
  local root=$1
  printf 'let f = builtins.getFlake "path:%s"; in import %s/tests/bootstrap-password-config-eval.nix { config = f.nixosConfigurations.remembrance.config; }' \
    "$root" "$root"
}

deps_check() {
  local root=$1 filter=$2
  nix eval --json --impure --expr "$(config_expr "$root")" | jq -e "$filter"
}

expect_pass() {
  local name=$1 root=$2 filter=$3
  if ! deps_check "$root" "$filter" > "$tmp/$name.log" 2>&1; then
    cat "$tmp/$name.log" >&2
    printf 'control-%s=FAIL\n' "$name" >&2
    exit 1
  fi
  printf 'control-%s=PASS\n' "$name"
}

materialize() {
  local name=$1 root="$tmp/$1"
  mkdir -p "$root"
  tar -C "$repo" \
    --exclude=./.git --exclude=./.direnv --exclude=./result --exclude='./result-*' \
    -cf - . | tar -x -C "$root"
  printf '%s\n' "$root"
}

expect_failure() {
  local name=$1 root=$2 expected=$3 rc
  shift 3
  set +e
  "$@" > "$tmp/$name.log" 2>&1
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    cat "$tmp/$name.log" >&2
    printf 'mutant-%s=SURVIVED\n' "$name" >&2
    exit 1
  fi
  if ! grep -Fq -- "$expected" "$tmp/$name.log"; then
    cat "$tmp/$name.log" >&2
    printf 'mutant-%s=FAILED-WRONG-REASON expected=%q\n' \
      "$name" "$expected" >&2
    exit 1
  fi
  printf 'mutant-%s=KILLED rc=%s reason=%q\n' "$name" "$rc" "$expected"
}

# Control: a mutation is only detectable because the pristine tree passes.
expect_pass hash-file "$repo" \
  '(.hashFile == "/var/lib/nixos-bootstrap/mei-password.hash")'
expect_pass validator-consumer "$repo" \
  '(.hasValidator == true) and (.hasConsumer == true)'
expect_pass user-deps "$repo" \
  '(.userDeps | index("bootstrapPasswordHash")) != null'
expect_pass consumer-deps "$repo" \
  '(.consumerDeps | index("users")) != null'
expect_pass mutable-users "$repo" \
  '(.mutableUsers == true)'
expect_pass classic-users "$repo" \
  '(.sysusers == false) and (.userborn == false)'
expect_pass no-plaintext "$repo" \
  '(.passwordSources.password == null) and (.passwordSources.initialPassword == null) and (.passwordSources.hashedPassword == null) and (.passwordSources.initialHashedPassword == null)'

root=$(materialize hash-file)
sed -i 's|/var/lib/nixos-bootstrap/|/var/lib/nixos-bootstrap-typo/|' \
  "$root/modules/nixos/bootstrap-password.nix"
expect_failure hash-file "$root" false deps_check "$root" \
  '(.hashFile == "/var/lib/nixos-bootstrap/mei-password.hash")'

root=$(materialize validator-comment)
sed -i 's|^  system.activationScripts.bootstrapPasswordHash = {|  system.activationScripts.disabledBootstrapPasswordHash = {|' \
  "$root/modules/nixos/bootstrap-password.nix"
expect_failure validator-comment "$root" false deps_check "$root" \
  '(.hasValidator == true)'

root=$(materialize user-ordering)
sed -i 's/system.activationScripts.users.deps = \[ "bootstrapPasswordHash" \];/system.activationScripts.users.deps = [ ];/' \
  "$root/modules/nixos/bootstrap-password.nix"
expect_failure user-ordering "$root" false deps_check "$root" \
  '(.userDeps | index("bootstrapPasswordHash")) != null'

root=$(materialize consumer-ordering)
sed -i '0,/deps = \[ "users" \];/s//deps = [ ];/' \
  "$root/modules/nixos/bootstrap-password.nix"
expect_failure consumer-ordering "$root" false deps_check "$root" \
  '(.consumerDeps | index("users")) != null'

root=$(materialize mutable-users)
sed -i 's/users.mutableUsers = true;/users.mutableUsers = false;/' \
  "$root/modules/nixos/bootstrap-password.nix"
expect_failure mutable-users "$root" false deps_check "$root" \
  '(.mutableUsers == true)'

root=$(materialize plaintext-password)
sed -i 's|users.users.${username}.hashedPasswordFile = bootstrapHashFile;|users.users.${username} = { password = "mutant-plaintext"; hashedPasswordFile = bootstrapHashFile; };|' \
  "$root/modules/nixos/bootstrap-password.nix"
expect_failure plaintext-password "$root" false deps_check "$root" \
  '(.passwordSources.password == null)'

printf 'mutation-control=PASS tmp=%s\n' "$tmp"
