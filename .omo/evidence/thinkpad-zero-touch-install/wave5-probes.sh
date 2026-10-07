set -u
WT=/home/mei/nixos-wt/thinkpad-zero-touch-install-wave5
MK=/nix/store/vn4jxcayjiid198w0dwpnbkxr6blwrpf-mkpasswd-5.6.6/bin
S=$(mktemp -d /tmp/ulw-w5-scratch.XXXXXX); echo "SCRATCH=$S"

note() { echo; echo "########## $* ##########"; }

mk_scratch() { # $1 = dest
  mkdir -p "$1"
  ( cd "$WT" && git archive HEAD ) | tar -x -C "$1"
}

# ---------- Todo 19 flip A: drop ' --host <host>' ----------
A=$S/t19A; mk_scratch "$A"
sed -i 's/ --host [^ ]*//' "$A/modules/flake/iso-images.nix"
note "T19 FLIP A (drop --host antagony)"
grep -n 'install.program' "$A/modules/flake/iso-images.nix"
( cd "$A" && nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}' ) 2>&1 | tail -6

# ---------- Todo 19 flip B: strip leading wrapper store-path token ----------
B=$S/t19B; mk_scratch "$B"
sed -i '/--rescue-identity/ s|^\( *\)[^ ]* |\1|' "$B/modules/flake/iso-images.nix"
note "T19 FLIP B (strip wrapper store-path token)"
grep -n 'install.program\|--rescue-identity' "$B/modules/flake/iso-images.nix"
( cd "$B" && nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}' ) 2>&1 | tail -6

# ---------- Todo 18: garbage mkpasswd stub ----------
C=$S/t18; mk_scratch "$C"
mkdir -p "$C/stubbin"
printf '#!/usr/bin/env bash\necho "GARBAGE-not-a-hash"\n' > "$C/stubbin/mkpasswd"
chmod +x "$C/stubbin/mkpasswd"
note "T18 GARBAGE MKPASSWD STUB (expect FAIL)"
( cd "$C" && PATH="$C/stubbin:$PATH" bash tests/install-staging.sh ) 2>&1 | tail -8
echo "T18_GARBAGE_RC=${PIPESTATUS[0]}"

# ---------- Todo 18 sanity: real mkpasswd control (should PASS) ----------
note "T18 CONTROL (real mkpasswd, expect PASS)"
( cd "$C" && PATH="$MK:$PATH" bash tests/install-staging.sh ) 2>&1 | tail -4

note "CLEANUP"
rm -rf "$S"
if [ -e "$S" ]; then echo "STILL_THERE $S"; else echo "removed $S"; fi
ls /dev/shm | grep nixos-install-staging || echo "no leftover /dev/shm stage dirs"
