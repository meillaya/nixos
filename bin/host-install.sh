#!/usr/bin/env bash
# Operator-side NixOS install orchestrator (skeleton).
# Plan: .omo/plans/install-on-main.md, todo 1: argument parser + safety guards.
# Stage bodies land in later todos; each stub exits 70 until implemented.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$root"

usage() {
  cat >&2 <<'EOF'
usage: bin/host-install.sh --target-host <ip> [options]

Enroll a freshly ISO-booted host, fold the artifacts into this repo, then
(optionally) install NixOS via nixos-anywhere and verify with nh.

options:
  --target-host <ip>  IP of the ISO-booted target (required)
  --host <name>       flake hostname to enroll/install (default: remembrance)
  --yes               confirm the destructive nixos-anywhere install
  --skip-install      enroll + fold + commit only; no build/install/verify
  --install-only      skip enroll/fold; run the build gate + install on the
                      already-enrolled worktree
  --skip-fold         keep the host key local: copy + commit the intake but do
                      not fold the host private key into the sops store
  --skip-verify       skip the post-install nh os switch stage
  --dry-run           print the exact command plan; execute nothing
  --extra-files <dir> stage <dir> into the target's /mnt before install
                      (forwarded to nixos-anywhere --extra-files)
  --chown <path> <owner>
                      chown -R /mnt/<path> <owner> after the extra-files copy;
                      repeatable (forwarded to nixos-anywhere --chown)
  --stage-identity <src>
                      additionally stage the age identity at <src> as the
                      installed user's own key (home/<user>/.config/sops/age/
                      keys.txt); off by default - the operator's own identity is
                      never staged implicitly. Operator entry point only;
                      ignored with --install-only

On the operator entry point (no --install-only) the script mints a per-install
password for the target's user, stages it for nixos-anywhere, and prints it once.
EOF
}

die_usage() {
  usage
  exit 64
}

target_host=""
host="remembrance"
assume_yes=false
skip_install=false
install_only=false
skip_fold=false
skip_verify=false
dry_run=false
extra_files=""
chown_args=()
stage_identity_src=""

# The installed account, and its numeric ownership on the target. The repo's
# machine identity fixes the user name (modules/entities/_machine-authority/
# model.nix: name = "mei", home = /home/mei); the conventional first account is
# 1000:100. nixos-anywhere --chown requires the numeric pair.
install_user="mei"
install_uid="1000"
install_gid="100"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-host)
      [[ $# -ge 2 ]] || die_usage
      target_host=$2
      shift 2
      ;;
    --host)
      [[ $# -ge 2 ]] || die_usage
      host=$2
      shift 2
      ;;
    --yes)
      assume_yes=true
      shift
      ;;
    --skip-install)
      skip_install=true
      shift
      ;;
    --install-only)
      install_only=true
      shift
      ;;
    --skip-fold)
      skip_fold=true
      shift
      ;;
    --skip-verify)
      skip_verify=true
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    --extra-files)
      [[ $# -ge 2 ]] || die_usage
      extra_files=$2
      shift 2
      ;;
    --chown)
      [[ $# -ge 3 ]] || die_usage
      chown_args+=("$2" "$3")
      shift 3
      ;;
    --stage-identity)
      [[ $# -ge 2 ]] || die_usage
      stage_identity_src=$2
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      die_usage
      ;;
  esac
done

# Artifact staging area for the enroll/retrieve stage (created by later todos).
tmpdir="${TMPDIR:-/tmp}/host-install.$$"

# Operator-path staging state, populated by stage_password_payload().
operator_stage=""
operator_chown_path=""
operator_chown_owner=""

# The operator entry point mints the per-install password and (only with
# --stage-identity) stages the age identity; --install-only callers (the install
# app) supply their own stage through --extra-files/--chown instead.
if [[ "$install_only" != true ]]; then
  # shellcheck source=bin/_install-staging.sh
  . "$root/bin/_install-staging.sh"
elif [[ -n "$stage_identity_src" ]]; then
  echo "warning: --stage-identity has no effect with --install-only; the caller supplies its own stage" >&2
fi

# The app wrapper puts mkpasswd on PATH via installDeps; a bare operator machine
# may not carry it, so resolve it from the flake's pinned nixpkgs when missing.
ensure_mkpasswd() {
  command -v mkpasswd >/dev/null 2>&1 && return 0
  local mkpasswd_out
  mkpasswd_out=$(nix eval --extra-experimental-features 'nix-command flakes' --raw \
    --inputs-from "$root" nixpkgs#mkpasswd.outPath) \
    || { echo "error: mkpasswd is not on PATH and could not be resolved from the flake's nixpkgs" >&2; exit 1; }
  PATH="${mkpasswd_out}/bin:$PATH"
  export PATH
}

# Mint the per-install password (and, with --stage-identity, the age identity)
# into the tmpfs stage that nixos-anywhere --extra-files copies into the target.
# The staging logic lives in bin/_install-staging.sh; never duplicate it here.
# Prints the password once, unless $1 is true (--dry-run suppresses that line).
stage_password_payload() {
  local quiet=${1:-false}
  ensure_mkpasswd

  staging_init >/dev/null || return 1
  operator_stage=$STAGING_DIR

  # A caller-supplied --extra-files tree is overlaid into the stage, so its
  # files still reach the target alongside the password and identity.
  if [[ "$quiet" != true && -n "$extra_files" ]]; then
    [[ -d "$extra_files" ]] \
      || { echo "error: --extra-files is not a directory: $extra_files" >&2; exit 1; }
    cp -a "$extra_files/." "$operator_stage/" \
      || { echo "error: cannot overlay --extra-files into the stage" >&2; exit 1; }
  fi

  if [[ "$quiet" == true ]]; then
    staging_password "$operator_stage" "$install_user" >/dev/null || return 1
  else
    staging_password "$operator_stage" "$install_user" || return 1
  fi

  if [[ -n "$stage_identity_src" ]]; then
    [[ -f "$stage_identity_src" ]] \
      || { echo "error: --stage-identity: file not found: $stage_identity_src" >&2; exit 1; }
    if [[ "$quiet" == true ]]; then
      staging_identity "$operator_stage" "$install_user" "$install_uid" "$install_gid" "$stage_identity_src" >/dev/null || return 1
    else
      staging_identity "$operator_stage" "$install_user" "$install_uid" "$install_gid" "$stage_identity_src" || return 1
    fi
    operator_chown_path="home/$install_user/.config"
    operator_chown_owner="$install_uid:$install_gid"
  fi
  return 0
}

print_plan() {
  local transport=""
  if [[ -n "$operator_stage" ]]; then
    transport+=" --extra-files ${operator_stage}"
  elif [[ -n "$extra_files" ]]; then
    transport+=" --extra-files ${extra_files}"
  fi
  local i
  for ((i = 0; i < ${#chown_args[@]}; i += 2)); do
    transport+=" --chown ${chown_args[i]} ${chown_args[i + 1]}"
  done
  if [[ -n "$operator_chown_path" ]]; then
    transport+=" --chown ${operator_chown_path} ${operator_chown_owner}"
  fi

  if [[ "$install_only" == true ]]; then
    echo "0-7. (skipped: --install-only)"
  else
    echo "0. PYTHONPATH=${root} python3 scripts/hardware/gen_trust.py --host ${host} -o ${tmpdir}/trust.json"
    echo "1. ssh root@${target_host} 'mkdir -p /root/enroll'"
    echo "2. scp trust.json root@${target_host}:/root/enroll/"
    echo "3. ssh root@${target_host} 'systemctl start hardware-enroll'"
    echo "4. scp -r root@${target_host}:/root/enroll/ ${tmpdir}/"
    echo "5. cp ${tmpdir}/${host}.json config/hosts/intake/${host}.json"
    echo "   cp ${tmpdir}/${host}.intake.json config/hosts/intake/${host}.intake.json"
    if [[ "$skip_fold" == true ]]; then
      echo "6. (skipped: --skip-fold) host key stays at ${tmpdir}/${host}.host-key"
    else
      echo "6. bin/nix-config-host-key-enroll ${tmpdir}/${host}.host-key ${host}"
    fi
    echo "7. git add config/hosts/intake/ [secrets/remembrance-keys.yaml] && git commit -m \"enroll: refresh ${host}\""
  fi
  if [[ -n "$operator_stage" ]]; then
    echo "   staging: var/lib/nixos-bootstrap/${install_user}-password.hash (0700 dir, 0600, yescrypt) under ${operator_stage}"
    if [[ -n "$operator_chown_path" ]]; then
      echo "   staging: age identity -> home/${install_user}/.config/sops/age/keys.txt"
    fi
    if [[ -n "$extra_files" ]]; then
      echo "   staging: overlays --extra-files ${extra_files} into the stage"
    fi
    echo "   staging: the plaintext password is printed once and never written to disk"
  fi
  echo "8. nh os build . -H ${host}"
  echo "9. : > /run/autoinstall-done"
  echo "   nix run github:nix-community/nixos-anywhere -- --flake .#${host} --target-host root@${target_host}${transport}"
  if [[ "$assume_yes" != true ]]; then
    echo "   REFUSING: install requires --yes"
  fi
  if [[ "$skip_verify" == true ]]; then
    echo "10. (skipped: --skip-verify)"
  else
    echo "10. nh os switch . -H ${host} --target-host ${target_host}"
  fi
}

stage_enroll() {
  mkdir -p "$tmpdir"

  if ! PYTHONPATH="$root" python3 scripts/hardware/gen_trust.py --host "$host" -o "$tmpdir/trust.json"; then
    echo "error: failed to generate canonical trust fixture (scripts/hardware/gen_trust.py --host $host)" >&2
    exit 1
  fi

  # The ISO oneshot only creates /root/enroll when it runs, so it must exist
  # before the trust fixture is pushed.
  ssh root@"$target_host" 'mkdir -p /root/enroll'
  scp "$tmpdir/trust.json" "root@$target_host:/root/enroll/trust.json"
  ssh root@"$target_host" 'systemctl start hardware-enroll'
  scp -r "root@$target_host:/root/enroll/." "$tmpdir/"

  # The oneshot ends with '|| true', so its exit code is meaningless; the
  # presence of the three artifacts is the real enrollment gate.
  missing=()
  for artifact in "${host}.json" "${host}.intake.json" "${host}.host-key"; do
    [[ -f "$tmpdir/$artifact" ]] || missing+=("$artifact")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "error: enrollment incomplete; missing artifact(s) in $tmpdir: ${missing[*]}" >&2
    echo "       hardware-enroll oneshot masks failures with '|| true'; check 'journalctl -u hardware-enroll' on the target, then re-run." >&2
    exit 1
  fi
}

stage_fold() {
  # The fold verifies the key against config/hosts/intake/$host.json on disk,
  # so the intake copies must land before it runs.
  cp "$tmpdir/$host.json" "config/hosts/intake/$host.json"
  cp "$tmpdir/$host.intake.json" "config/hosts/intake/$host.intake.json"

  if [[ "$skip_fold" == true ]]; then
    echo "warning: --skip-fold: host key is NOT folded into secrets/remembrance-keys.yaml; it stays at $tmpdir/$host.host-key and must be stored by the caller" >&2
  elif ! bin/nix-config-host-key-enroll "$tmpdir/$host.host-key" "$host"; then
    echo "error: host-key fold failed for $host; the retrieved key does not match the committed enrollment record (or sops re-encryption failed). Nothing was committed; aborting before build/install." >&2
    exit 1
  fi

  # Commit only after the fold: the sops file now embeds the folded host key,
  # and a clean checkout must carry it.
  git add config/hosts/intake/
  if [[ "$skip_fold" != true ]]; then
    git add secrets/remembrance-keys.yaml
  fi
  git commit -m "enroll: refresh $host"

  # A partial `git add` would silently omit a path from the commit.
  if [[ "$skip_fold" != true ]] && ! git diff-tree --no-commit-id --name-only -r HEAD | grep -q "secrets/remembrance-keys.yaml"; then
    echo "error: commit HEAD does not contain secrets/remembrance-keys.yaml; a clean checkout would miss the folded host key." >&2
    exit 1
  fi
  if ! git diff-tree --no-commit-id --name-only -r HEAD | grep -q "config/hosts/intake/$host.json"; then
    echo "error: commit HEAD does not contain config/hosts/intake/$host.json; a clean checkout would miss the enrollment record." >&2
    exit 1
  fi
}

stage_build_gate() {
  # Local build gate only: confirm the refreshed flake evaluates and builds
  # before the destructive install. No --target-host here; remote activation
  # is stage_verify's job.
  if ! nh os build . -H "$host"; then
    echo "error: pre-install nh os build failed for $host; refusing to install a flake that does not build" >&2
    exit 1
  fi
  echo "pre-flight build gate passed for $host"
}

stage_install() {
  # Defense in depth: the main flow only reaches this stage when not
  # --skip-install, but the destructive act itself re-checks the flag.
  if [[ "$assume_yes" != true ]]; then
    echo "refusing to install; pass --yes" >&2
    exit 1
  fi

  local -a transport=()
  if [[ -n "$operator_stage" ]]; then
    transport+=(--extra-files "$operator_stage")
  elif [[ -n "$extra_files" ]]; then
    transport+=(--extra-files "$extra_files")
  fi
  local i
  for ((i = 0; i < ${#chown_args[@]}; i += 2)); do
    transport+=(--chown "${chown_args[i]}" "${chown_args[i + 1]}")
  done
  if [[ -n "$operator_chown_path" ]]; then
    transport+=(--chown "$operator_chown_path" "$operator_chown_owner")
  fi

  # Attempt marker: written immediately before the destructive call so a
  # re-entrant run in this boot (the ISO unit guards on
  # ConditionPathExists=!/run/autoinstall-done) does not fire nixos-anywhere twice.
  : > /run/autoinstall-done

  if ! nix run github:nix-community/nixos-anywhere -- --flake ".#${host}" --target-host "root@${target_host}" "${transport[@]}"; then
    echo "error: nixos-anywhere install failed for $host; the target may be left partially partitioned" >&2
    exit 1
  fi
  echo "install completed for $host"
}

stage_verify() {
  # -H is required: without it nh defaults the hostname to the --target-host
  # value, which would try to build a config named <ip>.
  if ! nh os switch . -H "$host" --target-host "$target_host"; then
    echo "error: post-install nh os switch failed for $host; the system was installed but the verification switch did not complete" >&2
    exit 1
  fi
  echo "post-install verification passed for $host"
}

if [[ "$dry_run" == true ]]; then
  # Dry-run tolerates a missing --target-host: the plan prints with a placeholder.
  target_host=${target_host:-'<ip>'}
  # Mint the staging (validating mkpasswd and the identity source) but suppress
  # the password so the printed plan carries no secret.
  if [[ "$install_only" != true ]]; then
    stage_password_payload true
  fi
  print_plan
  exit 0
fi

[[ -n "$target_host" ]] || { echo "error: --target-host is required" >&2; die_usage; }

if [[ "$install_only" == true ]]; then
  stage_build_gate
  stage_install
else
  stage_enroll
  stage_fold

  if [[ "$skip_install" == true ]]; then
    exit 0
  fi

  # Mint and stage the password (and the identity with --stage-identity) before
  # the destructive install, so a missing mkpasswd or identity dies first.
  stage_password_payload
  stage_build_gate
  stage_install
fi

if [[ "$skip_verify" == true ]]; then
  echo "stage verify: skipped (--skip-verify)" >&2
else
  stage_verify
fi
