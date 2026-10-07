set -u
WT=/home/mei/nixos-wt/thinkpad-zero-touch-install-wave5
S=$(mktemp -d /tmp/ulw-w5-negctl.XXXXXX); echo "SCRATCH=$S"

mkdir -p "$S/tree"
( cd "$WT" && git archive HEAD ) | tar -x -C "$S/tree"
D="$S/tree"

sed -i 's/ --host [^ ]*//' "$D/modules/flake/iso-images.nix"

python3 - "$D/tests/dendritic-config-eval.nix" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
new = '''assert hasInfix (builtins.unsafeDiscardStringContext flake.apps.x86_64-linux.install.program) isoAutoinstallUnit.script;
assert hasInfix "--host antagony" isoAutoinstallUnit.script;'''
old = 'assert hasInfix "install" isoAutoinstallUnit.script;'
assert new in s, "new asserts not found"
s = s.replace(new, old)
open(p, "w").write(s)
print("[negctl] restored the pre-change assertion:", old)
PY

echo "--- mutated unit line ---"
grep -n 'install.program' "$D/modules/flake/iso-images.nix"
echo "--- pre-change assertion + mutation => expect OLD wall to PASS (tautology accepts it) ---"
( cd "$D" && nix-instantiate --eval --strict --expr 'import ./tests/dendritic-config-eval.nix {}' ) 2>&1 | tail -4

echo "--- cleanup ---"
rm -rf "$S"
[ -e "$S" ] && echo "STILL_THERE $S" || echo "removed $S"
