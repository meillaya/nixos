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
  echo "stage enroll: not implemented yet" >&2
  exit 70
}

stage_fold() {
  echo "stage fold: not implemented yet" >&2
  exit 70
}

stage_build_gate() {
  echo "stage build_gate: not implemented yet" >&2
  exit 70
}

stage_install() {
  echo "stage install: not implemented yet" >&2
  exit 70
}

stage_verify() {
  echo "stage verify: not implemented yet" >&2
  exit 70
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
