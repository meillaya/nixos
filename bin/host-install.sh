#!/usr/bin/env bash
# Operator-side NixOS install orchestrator (skeleton).
# Plan: .omo/plans/install-on-main.md — todo 1: argument parser + safety guards.
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
  --skip-verify       skip the post-install nh os switch stage
  --dry-run           print the exact command plan; execute nothing
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
skip_verify=false
dry_run=false

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
    --skip-verify)
      skip_verify=true
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      die_usage
      ;;
  esac
done

# Artifact staging area for the enroll/retrieve stage (created by later todos).
tmpdir="${TMPDIR:-/tmp}/host-install.$$"

print_plan() {
  echo "0. PYTHONPATH=${root} python3 scripts/hardware/gen_trust.py --host ${host} -o ${tmpdir}/trust.json"
  echo "1. ssh root@${target_host} 'mkdir -p /root/enroll'"
  echo "2. scp trust.json root@${target_host}:/root/enroll/"
  echo "3. ssh root@${target_host} 'systemctl start hardware-enroll'"
  echo "4. scp -r root@${target_host}:/root/enroll/ ${tmpdir}/"
  echo "5. cp ${tmpdir}/${host}.json config/hosts/intake/${host}.json"
  echo "   cp ${tmpdir}/${host}.intake.json config/hosts/intake/${host}.intake.json"
  echo "6. bin/nix-config-host-key-enroll ${tmpdir}/${host}.host-key ${host}"
  echo "7. git add config/hosts/intake/ secrets/remembrance-keys.yaml && git commit -m \"enroll: refresh ${host}\""
  echo "8. nh os build . -H ${host}"
  if [[ "$assume_yes" == true ]]; then
    echo "9. nix run github:nix-community/nixos-anywhere -- --flake .#${host} --target-host root@${target_host}"
  else
    echo "9. REFUSING: install requires --yes"
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

  if ! bin/nix-config-host-key-enroll "$tmpdir/$host.host-key" "$host"; then
    echo "error: host-key fold failed for $host; the retrieved key does not match the committed enrollment record (or sops re-encryption failed). Nothing was committed; aborting before build/install." >&2
    exit 1
  fi

  # Commit only after the fold: the sops file now embeds the folded host key,
  # and a clean checkout must carry it.
  git add config/hosts/intake/ secrets/remembrance-keys.yaml
  git commit -m "enroll: refresh $host"

  # A partial `git add` would silently omit a path from the commit.
  if ! git diff-tree --no-commit-id --name-only -r HEAD | grep -q "secrets/remembrance-keys.yaml"; then
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

  if ! nix run github:nix-community/nixos-anywhere -- --flake ".#${host}" --target-host "root@${target_host}"; then
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
  print_plan
  exit 0
fi

[[ -n "$target_host" ]] || { echo "error: --target-host is required" >&2; die_usage; }

stage_enroll
stage_fold

if [[ "$skip_install" == true ]]; then
  exit 0
fi

stage_build_gate
stage_install

if [[ "$skip_verify" == true ]]; then
  echo "stage verify: skipped (--skip-verify)" >&2
else
  stage_verify
fi
