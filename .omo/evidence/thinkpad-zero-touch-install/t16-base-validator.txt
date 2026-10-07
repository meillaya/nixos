hash_file=/var/lib/nixos-bootstrap/mei-password.hash
hash_dir=/var/lib/nixos-bootstrap
fail() {
  echo "bootstrap password hash validation failed: $1" >&2
  exit 1
}

has_unlocked_password() {
  test -r /etc/shadow && /nix/store/9zib1q94gka8i5q530364cvy25504qz5-gawk-5.4.1/bin/awk \
    -F: -v target_user=mei '
      $1 == target_user {
        found = 1
        if ($2 != "" && $2 !~ /^[!*]/) unlocked = 1
      }
      END { exit !(found && unlocked) }
    ' /etc/shadow
}

write_sentinel() {
  tmp="$(/nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/mktemp "$hash_dir/.mei-password.hash.XXXXXX")" \
    || fail "could not create sentinel temporary file"
  trap '/nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/rm -f "$tmp"' EXIT
  /nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/printf '!\n' > "$tmp"
  /nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/chown 0:0 "$tmp"
  /nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/chmod 0600 "$tmp"
  /nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/mv -f "$tmp" "$hash_file"
  trap - EXIT
}

test ! -L "$hash_dir" || fail "expected a real directory at $hash_dir"
if ! test -e "$hash_dir"; then
  has_unlocked_password || fail "missing $hash_file"
  /nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/install -d -o 0 -g 0 -m 0700 "$hash_dir" \
    || fail "could not create $hash_dir"
fi
test -d "$hash_dir" || fail "expected a directory at $hash_dir"
hash_dir_meta="$(/nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/stat -c '%u:%g:%a' "$hash_dir")" \
  || fail "could not inspect $hash_dir"
test "$hash_dir_meta" = "0:0:700" \
  || fail "expected numeric owner 0:0 mode 0700 on $hash_dir; got $hash_dir_meta"

test ! -L "$hash_file" || fail "expected a regular file at $hash_file"
if ! test -e "$hash_file"; then
  has_unlocked_password || fail "missing $hash_file"
  write_sentinel
fi

test -f "$hash_file" || fail "missing $hash_file"
hash_file_meta="$(/nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/stat -c '%u:%g:%a' "$hash_file")" \
  || fail "could not inspect $hash_file"
test "$hash_file_meta" = "0:0:600" \
  || fail "expected numeric owner 0:0 mode 0600 on $hash_file; got $hash_file_meta"
test -s "$hash_file" || fail "expected non-empty file"

last_byte="$(/nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/tail -c 1 "$hash_file" \
  | /nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/od -An -tuC \
  | /nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/tr -d '[:space:]')"
test "$last_byte" = 10 || fail "expected one newline-terminated line"
test "$(/nix/store/xjl7p8dvyk2j53kqf7f43kdj4ypbxz7g-coreutils-9.11/bin/wc -l < "$hash_file")" -eq 1 \
  || fail "expected exactly one newline-terminated line"

if /nix/store/xmvbzzxm5snla5a2cyfhm7hjy9bifx7n-gnugrep-3.12/bin/grep -qx '!' "$hash_file"; then
  # A consumed sentinel is valid only after an earlier activation installed
  # a real password. Reject it on a fresh machine or for a locked account.
  has_unlocked_password \
    || fail "consumed sentinel requires an existing unlocked password"
else
  /nix/store/xmvbzzxm5snla5a2cyfhm7hjy9bifx7n-gnugrep-3.12/bin/grep -Eqx \
    '^\$y\$[./A-Za-z0-9]+\$[./A-Za-z0-9]{1,86}\$[./A-Za-z0-9]{43}$' \
    "$hash_file" || fail "expected yescrypt hash"
fi
