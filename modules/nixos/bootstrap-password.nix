{ identity }:
{ config, lib, pkgs, ... }:
let
  username = identity.name;
  bootstrapFileName = "${username}-password.hash";
  bootstrapHashFile = "/var/lib/nixos-bootstrap/${bootstrapFileName}";
in
{
  users.mutableUsers = true;
  users.users.${username}.hashedPasswordFile = bootstrapHashFile;

  system.activationScripts.bootstrapPasswordHash = {
    deps = [ ];
    text = ''
      hash_file=${lib.escapeShellArg bootstrapHashFile}
      hash_dir=${lib.escapeShellArg (builtins.dirOf bootstrapHashFile)}
      fail() {
        echo "bootstrap password hash validation failed: $1" >&2
        exit 1
      }

      has_unlocked_password() {
        test -r /etc/shadow && ${pkgs.gawk}/bin/awk \
          -F: -v target_user=${lib.escapeShellArg username} '
            $1 == target_user {
              found = 1
              if ($2 != "" && $2 !~ /^[!*]/) unlocked = 1
            }
            END { exit !(found && unlocked) }
          ' /etc/shadow
      }

      write_sentinel() {
        tmp="$(${pkgs.coreutils}/bin/mktemp "$hash_dir/.${bootstrapFileName}.XXXXXX")" \
          || fail "could not create sentinel temporary file"
        trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
        ${pkgs.coreutils}/bin/printf '!\n' > "$tmp"
        ${pkgs.coreutils}/bin/chown 0:0 "$tmp"
        ${pkgs.coreutils}/bin/chmod 0600 "$tmp"
        ${pkgs.coreutils}/bin/mv -f "$tmp" "$hash_file"
        trap - EXIT
      }

      test ! -L "$hash_dir" || fail "expected a real directory at $hash_dir"
      if ! test -e "$hash_dir"; then
        has_unlocked_password || fail "missing $hash_file"
        ${pkgs.coreutils}/bin/install -d -o 0 -g 0 -m 0700 "$hash_dir" \
          || fail "could not create $hash_dir"
      fi
      test -d "$hash_dir" || fail "expected a directory at $hash_dir"
      hash_dir_meta="$(${pkgs.coreutils}/bin/stat -c '%u:%g:%a' "$hash_dir")" \
        || fail "could not inspect $hash_dir"
      test "$hash_dir_meta" = "0:0:700" \
        || fail "expected numeric owner 0:0 mode 0700 on $hash_dir; got $hash_dir_meta"

      test ! -L "$hash_file" || fail "expected a regular file at $hash_file"
      if ! test -e "$hash_file"; then
        has_unlocked_password || fail "missing $hash_file"
        write_sentinel
      fi

      test -f "$hash_file" || fail "missing $hash_file"
      hash_file_meta="$(${pkgs.coreutils}/bin/stat -c '%u:%g:%a' "$hash_file")" \
        || fail "could not inspect $hash_file"
      test "$hash_file_meta" = "0:0:600" \
        || fail "expected numeric owner 0:0 mode 0600 on $hash_file; got $hash_file_meta"
      test -s "$hash_file" || fail "expected non-empty file"

      last_byte="$(${pkgs.coreutils}/bin/tail -c 1 "$hash_file" \
        | ${pkgs.coreutils}/bin/od -An -tuC \
        | ${pkgs.coreutils}/bin/tr -d '[:space:]')"
      test "$last_byte" = 10 || fail "expected one newline-terminated line"
      test "$(${pkgs.coreutils}/bin/wc -l < "$hash_file")" -eq 1 \
        || fail "expected exactly one newline-terminated line"

      if ${pkgs.gnugrep}/bin/grep -qx '!' "$hash_file"; then
        # A consumed sentinel is valid only after an earlier activation installed
        # a real password. Reject it on a fresh machine or for a locked account.
        has_unlocked_password \
          || fail "consumed sentinel requires an existing unlocked password"
      else
        ${pkgs.gnugrep}/bin/grep -Eqx \
          '^\$y\$[./A-Za-z0-9]+\$[./A-Za-z0-9]{1,86}\$[./A-Za-z0-9]{43}$' \
          "$hash_file" || fail "expected yescrypt hash"
      fi
    '';
  };

  # Validate the staged verifier before the stock users fragment reads it.
  system.activationScripts.users.deps = [ "bootstrapPasswordHash" ];

  # Remove the duplicate verifier after /etc/shadow has been updated. Mutable user
  # semantics preserve the real shadow password on subsequent rebuilds.
  system.activationScripts.consumeBootstrapPassword = {
    deps = [ "users" ];
    text = ''
      hash_file=${lib.escapeShellArg bootstrapHashFile}
      hash_dir=${lib.escapeShellArg (builtins.dirOf bootstrapHashFile)}
      if ! ${pkgs.gnugrep}/bin/grep -qx '!' "$hash_file"; then
        ${pkgs.gawk}/bin/awk -F: -v target_user=${lib.escapeShellArg username} '
          NR == FNR { expected = $0; next }
          $1 == target_user && $2 == expected { installed = 1 }
          END { exit !installed }
        ' "$hash_file" /etc/shadow || {
          echo "bootstrap password hash was not installed for ${username}; preserving verifier" >&2
          exit 1
        }
        test ! -L "$hash_dir"
        hash_dir_meta="$(${pkgs.coreutils}/bin/stat -c '%u:%g:%a' "$hash_dir")" || {
          echo "bootstrap password hash consumption failed: could not inspect $hash_dir" >&2
          exit 1
        }
        test "$hash_dir_meta" = "0:0:700" || {
          echo "bootstrap password hash consumption failed: expected numeric owner 0:0 mode 0700 on $hash_dir; got $hash_dir_meta" >&2
          exit 1
        }
        tmp="$(${pkgs.coreutils}/bin/mktemp "$hash_dir/.${bootstrapFileName}.XXXXXX")"
        trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
        ${pkgs.coreutils}/bin/printf '!\n' > "$tmp"
        ${pkgs.coreutils}/bin/chown 0:0 "$tmp"
        ${pkgs.coreutils}/bin/chmod 0600 "$tmp"
        ${pkgs.coreutils}/bin/mv -f "$tmp" "$hash_file"
        trap - EXIT
      fi
    '';
  };

  assertions = [
    {
      assertion = config.users.mutableUsers;
      message = "bootstrap password sentinel requires mutable users";
    }
    {
      assertion = !config.systemd.sysusers.enable && !config.services.userborn.enable;
      message = "bootstrap password ordering requires classic users activation";
    }
  ];
}
