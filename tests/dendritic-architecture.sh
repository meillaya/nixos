#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

a=modules/aspects

grep -Fq 'inputs.flake-parts.lib.mkFlake' flake.nix
grep -Fq 'inputs.import-tree ./modules' flake.nix
grep -Fq 'github:denful/den/1614f6f8ed435c5bb257408bf91fd662f9aac43e' flake.nix
grep -Fq 'inputs.den.flakeModules.strict' modules/flake/dendritic.nix
grep -Fq 'inputs.import-tree ../aspects' modules/flake/dendritic.nix
grep -Fq 'options.homeDirectory = lib.mkOption' $a/schema.nix
grep -Fq 'options.machine = lib.mkOption' $a/schema.nix
grep -Fq 'options.identity = lib.mkOption' $a/schema.nix
grep -Fq 'machineType = lib.types.submodule' $a/schema.nix

if grep -A2 -F 'options.machine = lib.mkOption' $a/schema.nix \
  | grep -Eq 'type = lib\.types\.(attrs|raw);'; then
  echo 'host/home machine schema is still generic attrs/raw' >&2
  exit 1
fi

if grep -A2 -F 'options.identity = lib.mkOption' $a/schema.nix \
  | grep -Eq 'type = lib\.types\.(attrs|raw);'; then
  echo 'user identity schema is still generic attrs/raw' >&2
  exit 1
fi
grep -A2 -F 'options.identity = lib.mkOption' $a/schema.nix \
  | grep -Fq 'type = identityType;'

for path in \
  modules/flake/dendritic.nix \
  modules/flake/outputs.nix \
  $a/authority.nix \
  $a/inventory.nix \
  $a/_machine-authority/model.nix \
  $a/_machine-authority/validators.nix \
  $a/nixpkgs.nix \
  $a/linux.nix \
  $a/workstation-linux.nix \
  $a/pending-x86-workstation.nix \
  $a/x86-vendor-routing.nix \
  $a/device-capability-routing.nix \
  $a/storage-remembrance.nix \
  $a/remembrance.nix \
  $a/mei.nix \
  $a/bootstrap-password.nix \
  $a/nixos-base.nix \
  $a/niri.nix \
  $a/desktop-media.nix \
  $a/linux-desktop.nix \
  $a/sops.nix
do
  test -f "$path"
done

# The flat aspects dir is the only import-tree root. Raw NixOS / nix-darwin /
# home-manager payload stays in its own top-level trees, reached by explicit
# import, so a payload module can never be auto-imported as a flake module.
for legacy in \
  modules/aspects/features modules/aspects/hardware modules/aspects/hosts \
  modules/aspects/named-hosts modules/aspects/platforms modules/aspects/roles \
  modules/aspects/shared-policy modules/aspects/storage modules/aspects/users \
  modules/entities
do
  if test -e "$legacy"; then
    echo "sub-classification folder returned; aspects are flat: $legacy" >&2
    exit 1
  fi
done

if ! test -f modules/shared/config/fastfetch/snoopy-mugiwara.png; then
  echo 'Darwin Fastfetch profile is missing the configured Snoopy logo asset' >&2
  exit 1
fi

grep -Fq '"source": "~/.config/fastfetch/snoopy-mugiwara.png"' \
  modules/shared/config/fastfetch/config.jsonc

# Logo must use inline Kitty transmission (`t=d`), not file transmission
# (`kitty-direct` -> `t=f`): KDE Konsole only supports inline, and rejects
# `t=f` by leaking `Gi=0;ENOTSUPPORTED:` onto the screen.
grep -Fq '"type": "kitty"' modules/shared/config/fastfetch/config.jsonc

fastfetch_home=$(mktemp -d "${TMPDIR:-/tmp}/fastfetch-profile.XXXXXX")
fastfetch_output=$(mktemp "${TMPDIR:-/tmp}/fastfetch-output.XXXXXX")
trap 'rm -rf "$fastfetch_home" "$fastfetch_output"' EXIT
mkdir -p "$fastfetch_home/.config"
cp -R modules/shared/config/fastfetch "$fastfetch_home/.config/fastfetch"

HOME="$fastfetch_home" TERM=xterm-kitty KITTY_WINDOW_ID=1 \
  fastfetch \
    --config "$fastfetch_home/.config/fastfetch/config.jsonc" \
    --pipe false \
    --structure OS > "$fastfetch_output"

if grep -aFq 'a=T,f=100,t=f' "$fastfetch_output"; then
  echo 'Fastfetch profile still emits the Kitty file-transmission (t=f) sequence that KDE Konsole rejects with ENOTSUPPORTED' >&2
  exit 1
fi

if grep -Eq 'nixpkgs\.lib\.nixosSystem|darwin\.lib\.darwinSystem|homeManagerConfiguration' flake.nix; then
  echo 'flake.nix still manually constructs configuration entities' >&2
  exit 1
fi

if grep -R -E 'den\.ctx|mutual-provider|mutualProvider' --include='*.nix' modules flake.nix; then
  echo 'deprecated Den compatibility API detected' >&2
  exit 1
fi

# Retired aliases: Den selects an entity's aspect by the entity's own name
# (lookupAspect den config), so an aspect keyed on a system or on a generic
# role name is never selected. Keep them from creeping back.
if grep -R -Eq 'den\.aspects\.(x86_64-linux|nixos-workstation|darwin-workstation|massive-aarch64|qualifier-role-linux|evaluation-role-linux)\b' \
  --include='*.nix' modules; then
  echo 'unselectable compatibility alias aspect returned' >&2
  exit 1
fi

if grep -Eq 'nixpkgsPolicy|pkgs[[:space:]]*=' $a/inventory.nix; then
  echo 'Den entity declarations contain non-identity package policy' >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*(aspect|includes|nixos|darwin|homeManager)[[:space:]]*=' \
  $a/inventory.nix; then
  echo 'Den entity declarations contain behavior or aspect selection' >&2
  exit 1
fi

if grep -R -Fq 'x86_64-darwin' \
  $a/inventory.nix modules/flake/systems.nix \
  modules/flake/apps.nix; then
  echo 'unsupported x86_64-darwin output remains in the Dendritic graph' >&2
  exit 1
fi

test ! -e apps/x86_64-darwin

grep -Fq 'den.aspects.linux-platform' $a/linux.nix
grep -Fq 'den.aspects.workstation-role-linux' $a/workstation-linux.nix
grep -Fq 'den.aspects.pending-x86-workstation-hardware' \
  $a/pending-x86-workstation.nix
grep -Fq 'den.aspects.remembrance-storage' $a/storage-remembrance.nix
grep -Fq 'den.aspects.remembrance' $a/remembrance.nix

# Machine data reaches an aspect only through the Den entity context
# (`host.machine`). No aspect may import the global authority directly: the
# inventory and the ISO builder are the only two sanctioned readers.
if grep -R -Eq '_machine-authority|authority\.getMachine' \
  --include='*.nix' $a; then
  if grep -R -El '_machine-authority|authority\.getMachine' \
    --include='*.nix' $a | grep -vE '_machine-authority/|/(inventory|authority)\.nix$'; then
    echo 'an aspect imports the global machine authority instead of host.machine' >&2
    exit 1
  fi
fi

# Every host-attached aspect projects the active entity, never a literal id.
for path in \
  $a/remembrance.nix \
  $a/antagony.nix \
  $a/entropy.nix \
  $a/x86-vendor-routing.nix \
  $a/device-capability-routing.nix \
  $a/storage-remembrance.nix \
  $a/storage-antagony.nix \
  $a/storage-entropy.nix \
  $a/enrolled-x86.nix \
  $a/enrolled-x86-workstation.nix \
  $a/pending-x86-workstation.nix \
  $a/apple-silicon.nix \
  $a/sops.nix \
  $a/rootless-containers.nix \
  $a/bootstrap-password.nix
do
  grep -Fq 'host.machine' "$path"
done

grep -Fq 'machine.capabilities.values."install.remote".state' \
  $a/x86-vendor-routing.nix
if grep -Fq 'machine.capabilities.values.install.remote' \
  $a/x86-vendor-routing.nix; then
  echo 'flat install.remote capability key is accessed as nested attributes' >&2
  exit 1
fi

grep -Fq 'system = "x86_64-linux";' $a/inventory.nix
grep -Fq '"home":"/home/mei"' config/hosts/intake/remembrance.json
grep -Fq 'den.aspects.enrolled-x86-storage' $a/enrolled-x86.nix
grep -Fq 'den.aspects.enrolled-x86-workstation-hardware' $a/enrolled-x86-workstation.nix

printf '%s\n' 'dendritic-architecture=PASS'
