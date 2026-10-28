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

grep -Fq 'options.identity = lib.mkOption' $a/schema.nix
if grep -Eq 'machineType|options\.machine|machineAuthority' $a/schema.nix; then
  echo 'machine-authority schema returned; host data is plain Den user identity now' >&2
  exit 1
fi

for path in \
  modules/flake/dendritic.nix \
  modules/flake/outputs.nix \
  modules/flake/iso-images.nix \
  $a/inventory.nix \
  $a/schema.nix \
  $a/nixpkgs.nix \
  $a/linux.nix \
  $a/workstation-linux.nix \
  $a/remembrance.nix \
  $a/antagony.nix \
  $a/entropy.nix \
  $a/live.nix \
  $a/installed.nix \
  $a/distro-platform.nix \
  $a/distro-role.nix \
  $a/storage-labels.nix \
  $a/x86-hardware.nix \
  $a/mei.nix \
  $a/nixos-base.nix \
  $a/niri.nix \
  $a/desktop-media.nix \
  $a/linux-desktop.nix \
  $a/sops.nix \
  modules/distro/identity.nix \
  modules/distro/base.nix \
  modules/distro/live.nix \
  modules/distro/installed.nix \
  modules/distro/iso.nix \
  modules/distro/installer.nix \
  modules/nixos/storage-labels.nix \
  pkgs/distro-installer.nix \
  scripts/distro/install.py \
  tests/installer-disk-vm.nix
do
  test -f "$path" || {
    echo "missing expected file: $path" >&2
    exit 1
  }
done

for retired in \
  modules/aspects/_machine-authority \
  modules/aspects/authority.nix \
  modules/aspects/bootstrap-password.nix \
  modules/aspects/storage.nix \
  modules/aspects/storage-remembrance.nix \
  modules/aspects/storage-antagony.nix \
  modules/aspects/storage-entropy.nix \
  modules/aspects/enrolled-x86.nix \
  modules/aspects/enrolled-x86-workstation.nix \
  modules/aspects/pending-x86-workstation.nix \
  modules/aspects/x86-vendor-routing.nix \
  modules/aspects/device-capability-routing.nix \
  modules/aspects/apple-silicon.nix \
  modules/nixos/bootstrap-password.nix \
  modules/nixos/disk-config.nix \
  config/hosts \
  config/install \
  scripts/hardware \
  scripts/readiness \
  scripts/support \
  pkgs/enrollment-tooling.nix \
  apps/x86_64-linux/install \
  tests/readiness \
  tests/iso-autostart-vm.nix \
  tests/install-staging.sh \
  tests/bootstrap-password-config-eval.nix \
  tests/bootstrap-password-lifecycle.sh \
  tests/bootstrap-password-mutations.sh \
  tests/bootstrap-password-secret-scan.sh
do
  if test -e "$retired"; then
    echo "retired machine-authority or enrollment file returned: $retired" >&2
    exit 1
  fi
done

if grep -R -E '_machine-authority|machineAuthority|host\.machine|diskById|config/hosts/intake|hardware-enroll|nixos\.autoinstall' \
  --include='*.nix' --include='*.sh' --include='*.py' \
  modules flake.nix apps bin scripts 2>/dev/null \
  | grep -v '__pycache__'; then
  echo 'machine-authority or enrollment reference remains in active code' >&2
  exit 1
fi

if grep -R -E 'specialArgs|extraSpecialArgs' \
  --include='*.nix' flake.nix modules/flake modules/aspects 2>/dev/null; then
  echo 'hidden specialArgs coupling remains in the dendritic graph' >&2
  exit 1
fi

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

if grep -Eq 'nixpkgs\.lib\.nixosSystem|darwin\.lib\.darwinSystem|homeManagerConfiguration' flake.nix; then
  echo 'flake.nix still manually constructs configuration entities' >&2
  exit 1
fi

if grep -R -E 'den\.ctx|mutual-provider|mutualProvider' --include='*.nix' modules flake.nix; then
  echo 'deprecated Den compatibility API detected' >&2
  exit 1
fi

if grep -R -Eq 'den\.aspects\.(x86_64-linux|nixos-workstation|darwin-workstation|massive-aarch64|qualifier-role-linux|evaluation-role-linux)\b' \
  --include='*.nix' modules; then
  echo 'unselectable compatibility alias aspect returned' >&2
  exit 1
fi

if grep -Eq 'nixpkgsPolicy|pkgs[[:space:]]*=' $a/inventory.nix; then
  echo 'Den entity declarations contain non-identity package policy' >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*(aspect|includes|nixos|darwin|homeManager|machine)[[:space:]]*=' \
  $a/inventory.nix; then
  echo 'Den entity declarations contain behavior, aspect selection, or machine data' >&2
  exit 1
fi

for identity in remembrance antagony live installed; do
  grep -Fq "${identity}.users.mei.identity" $a/inventory.nix
done
grep -Fq 'entropy.users.mei.identity' $a/inventory.nix
grep -Fq 'den.homes' $a/inventory.nix

if grep -R -Fq 'x86_64-darwin' \
  $a/inventory.nix modules/flake/systems.nix \
  modules/flake/apps.nix; then
  echo 'unsupported x86_64-darwin output remains in the Dendritic graph' >&2
  exit 1
fi

test ! -e apps/x86_64-darwin

grep -Fq 'den.aspects.linux-platform' $a/linux.nix
grep -Fq 'den.aspects.workstation-role-linux' $a/workstation-linux.nix
grep -Fq 'den.aspects.storage-labels' $a/remembrance.nix
grep -Fq 'den.aspects.storage-labels' $a/installed.nix

grep -Fq '/dev/disk/by-label/NIXROOT' modules/nixos/storage-labels.nix
grep -Fq '/dev/disk/by-label/NIXBOOT' modules/nixos/storage-labels.nix

grep -Fq 'host.users.mei.identity' modules/nixos/system.nix
grep -Fq 'host.users.mei.identity' modules/darwin/base.nix
grep -Fq 'host.users.mei.identity' modules/darwin/system.nix
grep -Fq 'host.users.mei.identity' $a/sops.nix
grep -Fq 'host.users.mei.identity' $a/rootless-containers.nix

printf '%s\n' 'dendritic-architecture=PASS'
