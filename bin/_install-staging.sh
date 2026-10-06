#!/usr/bin/env bash
# Private staging builder, sourced by apps/x86_64-linux/install and
# bin/host-install.sh; never executed directly. It populates the tree that
# `nixos-anywhere --extra-files` copies into the target root.
#
# The hash contract mirrors modules/nixos/bootstrap-password.nix:
#   /var/lib/nixos-bootstrap/<user>-password.hash = one LF-terminated yescrypt
#   line, file mode 0600 in a root-owned 0700 directory, matching
#   ^\$y\$[./A-Za-z0-9]+\$[./A-Za-z0-9]{1,86}\$[./A-Za-z0-9]{43}$
# The stage must live on tmpfs, the plaintext password must never be written to
# disk, and this helper must never chown: the caller forwards the reported
# ownership target to nixos-anywhere --chown.
#
# Sourcing does not change the caller's shell options; every fallible step is
# guarded explicitly, so the helper is correct with or without set -e.

_STAGING_BOOTSTRAP_DIR="var/lib/nixos-bootstrap"
_STAGING_ENROLL_DIR="var/lib/nixos-enrollment"
_STAGING_HASH_REGEX='^\$y\$[./A-Za-z0-9]+\$[./A-Za-z0-9]{1,86}\$[./A-Za-z0-9]{43}$'

STAGING_DIR=""
STAGING_DIRS=()

_staging_die() {
  printf 'install-staging: %s\n' "$*" >&2
  return 1
}

_staging_cleanup() {
  local dir
  for dir in "${STAGING_DIRS[@]}"; do
    [[ -n $dir ]] && rm -rf -- "$dir"
  done
}

_staging_tmpfs_base() {
  local candidate
  for candidate in "${XDG_RUNTIME_DIR:-}" "/run/user/$(id -u)" /dev/shm /run; do
    [[ -n $candidate && -d $candidate && -w $candidate ]] || continue
    if [[ "$(stat -f -c %T -- "$candidate" 2>/dev/null)" == tmpfs ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# Call directly, not as $(staging_init): a command substitution would run the
# EXIT trap in its own subshell and delete the stage before the caller uses it.
# The path is printed and also left in $STAGING_DIR.
staging_init() {
  local base dir
  base=$(_staging_tmpfs_base) \
    || { _staging_die "no writable tmpfs mount found for the install stage"; return 1; }
  dir=$(mktemp -d -- "${base%/}/nixos-install-staging.XXXXXXXX") \
    || { _staging_die "cannot create a stage under $base"; return 1; }
  STAGING_DIRS+=("$dir")
  STAGING_DIR=$dir
  trap '_staging_cleanup' EXIT
  printf '%s\n' "$dir"
}

staging_password() {
  local stage="${1:-}" user="${2:-}"
  [[ -n $stage && -n $user ]] \
    || { _staging_die "usage: staging_password <stage> <user>"; return 1; }
  [[ -d $stage ]] || { _staging_die "stage is not a directory: $stage"; return 1; }
  case "$user" in
    ''|*/*|*[!A-Za-z0-9._-]*) _staging_die "unsafe username: $user"; return 1 ;;
  esac

  local pw hash dir file

  # head is the producer, so no stage receives SIGPIPE; the length check below
  # rejects a short read regardless of the caller's pipefail setting.
  pw=$(head -c 512 /dev/urandom | base64 -w0 | tr -dc 'A-Za-z0-9' | cut -c1-24)
  [[ ${#pw} -eq 24 ]] \
    || { _staging_die "password generation produced ${#pw} characters"; return 1; }

  hash=$(printf '%s\n' "$pw" | mkpasswd --method=yescrypt --stdin) \
    || { _staging_die "mkpasswd failed to hash the password"; return 1; }
  # Validate before writing: a hash the activation validator would reject must
  # never reach the stage.
  if ! printf '%s\n' "$hash" | grep -Eqx -- "$_STAGING_HASH_REGEX"; then
    _staging_die "generated hash does not match the bootstrap validator regex"
    return 1
  fi

  dir="$stage/$_STAGING_BOOTSTRAP_DIR"
  file="$dir/${user}-password.hash"
  install -d -m 0700 -- "$dir" || { _staging_die "cannot create $dir"; return 1; }
  ( umask 077; printf '%s\n' "$hash" > "$file" ) \
    || { _staging_die "cannot write $file"; return 1; }
  chmod 0600 -- "$file" || { _staging_die "cannot set mode on $file"; return 1; }

  # Ownership 0:0 is only assertable when running as root; a non-root staging
  # run cannot (and must not) chown, and nixos-anywhere restores 0:0 on extract.
  local dmeta fmeta
  dmeta=$(stat -c '%a' -- "$dir") || { _staging_die "cannot stat $dir"; return 1; }
  fmeta=$(stat -c '%a' -- "$file") || { _staging_die "cannot stat $file"; return 1; }
  [[ $dmeta == 700 ]] || { _staging_die "expected mode 0700 on $dir; got $dmeta"; return 1; }
  [[ $fmeta == 600 ]] || { _staging_die "expected mode 0600 on $file; got $fmeta"; return 1; }
  if (( EUID == 0 )); then
    [[ "$(stat -c '%u:%g' -- "$dir")" == 0:0 ]] \
      || { _staging_die "expected owner 0:0 on $dir"; return 1; }
    [[ "$(stat -c '%u:%g' -- "$file")" == 0:0 ]] \
      || { _staging_die "expected owner 0:0 on $file"; return 1; }
  fi
  [[ -s $file ]] || { _staging_die "staged hash is empty: $file"; return 1; }

  printf 'password for %s: %s\n' "$user" "$pw"
  unset pw hash
  return 0
}

# staging_artifacts <stage> <file>... - stage enrollment artifacts 0600.
staging_artifacts() {
  local stage="${1:-}"
  [[ -n $stage && -d $stage ]] \
    || { _staging_die "usage: staging_artifacts <stage> <file>..."; return 1; }
  shift
  (( $# > 0 )) || { _staging_die "staging_artifacts needs at least one file"; return 1; }

  local dir="$stage/$_STAGING_ENROLL_DIR" src
  install -d -m 0700 -- "$dir" || { _staging_die "cannot create $dir"; return 1; }
  for src in "$@"; do
    [[ -f $src ]] || { _staging_die "artifact not found: $src"; return 1; }
    install -m 0600 -- "$src" "$dir/$(basename -- "$src")" \
      || { _staging_die "cannot stage $src"; return 1; }
  done
  [[ "$(stat -c '%a' -- "$dir")" == 700 ]] \
    || { _staging_die "expected mode 0700 on $dir"; return 1; }
  return 0
}

# staging_identity <stage> <user> <uid> <gid> <keyfile> - stage the age identity
# at home/<user>/.config/sops/age/keys.txt (0600). Prints the ownership pair the
# caller must forward to nixos-anywhere --chown; it never chowns by itself.
staging_identity() {
  local stage="${1:-}" user="${2:-}" uid="${3:-}" gid="${4:-}" keyfile="${5:-}"
  [[ -n $stage && -n $user && -n $uid && -n $gid && -n $keyfile ]] \
    || { _staging_die "usage: staging_identity <stage> <user> <uid> <gid> <keyfile>"; return 1; }
  [[ -d $stage ]] || { _staging_die "stage is not a directory: $stage"; return 1; }
  [[ -f $keyfile ]] || { _staging_die "age identity not found: $keyfile"; return 1; }

  local rel="home/$user/.config"
  local top="$stage/home/$user"
  local dir="$top/.config/sops/age"
  mkdir -p -- "$dir" || { _staging_die "cannot create $dir"; return 1; }
  # Ancestors stay 0755 so the home path is traversable even though only the
  # .config subtree is handed to the user by the caller's --chown argument.
  chmod 0755 -- "$stage/home" "$top" \
    || { _staging_die "cannot set modes under $stage/home"; return 1; }
  chmod 0700 -- "$top/.config" "$top/.config/sops" "$dir" \
    || { _staging_die "cannot set modes under $top/.config"; return 1; }
  install -m 0600 -- "$keyfile" "$dir/keys.txt" \
    || { _staging_die "cannot stage the age identity"; return 1; }
  [[ "$(stat -c '%a' -- "$dir/keys.txt")" == 600 ]] \
    || { _staging_die "expected mode 0600 on the staged identity"; return 1; }

  printf 'staging identity: %s -> %s/sops/age/keys.txt (forward --chown %s %s:%s)\n' \
    "$keyfile" "$rel" "$rel" "$uid" "$gid"
  return 0
}
