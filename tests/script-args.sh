#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/script-args.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/nh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$NH_ARGS_FILE"
EOF
chmod +x "$tmpdir/nh"

run_switch() {
  NH_ARGS_FILE="$tmpdir/args" PATH="$tmpdir:$PATH" \
    bash "$root/apps/x86_64-linux/build-switch" "$@"
}

# The explicit host and every pass-through argument must reach nh.
run_switch --host antagony -- --dry
mapfile -t args < "$tmpdir/args"
printf '%s\n' "${args[@]}" | grep -Fxq 'antagony'
printf '%s\n' "${args[@]}" | grep -Fxq -- '--dry'

# A bare switch must target the current host, never remembrance by default.
run_switch
mapfile -t args < "$tmpdir/args"
current_host=$(hostname -s)
printf '%s\n' "${args[@]}" | grep -Fxq "$current_host"
if printf '%s\n' "${args[@]}" | grep -Fxq 'remembrance' && [ "$current_host" != "remembrance" ]; then
  printf '%s\n' 'bare build-switch fell back to remembrance' >&2
  exit 1
fi

# Arguments can also be passed without the `--` separator.
run_switch --host=antagony --dry
mapfile -t args < "$tmpdir/args"
printf '%s\n' "${args[@]}" | grep -Fxq -- '--dry'
printf '%s\n' "${args[@]}" | grep -Fxq 'antagony'

printf '%s\n' 'script-args=PASS'
