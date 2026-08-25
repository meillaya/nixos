{ inputs, lib, ... }:
let
  inherit (inputs) self home-manager nixpkgs;
  mkConfiguredPkgs = (import ../../lib/nixpkgs.nix { inherit inputs; }).mkPkgs;
  localUpdaterNamesFor = _system: [ ];
  mkApp = scriptName: system: {
    type = "app";
    program = "${(nixpkgs.legacyPackages.${system}.writeScriptBin scriptName ''
      #!/usr/bin/env bash
      PATH=${nixpkgs.legacyPackages.${system}.git}/bin:$PATH
      echo "Running ${scriptName} for ${system}"
      exec ${self}/apps/${system}/${scriptName} "$@"
    '')}/bin/${scriptName}";
  };
  mkSearchPkgsApp = system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      type = "app";
      program = "${(pkgs.writeShellScriptBin "search-pkgs" ''
        set -euo pipefail

        unstable_ref="''${NIXPKGS_SEARCH_UNSTABLE_REF:-github:nixos/nixpkgs/nixos-unstable}"
        stable_ref="''${NIXPKGS_SEARCH_STABLE_REF:-github:nixos/nixpkgs/nixos-25.11}"
        limit="''${NIXPKGS_SEARCH_LIMIT:-20}"
        query_args=()

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --stable-ref)
              stable_ref="$2"
              shift 2
              ;;
            --unstable-ref)
              unstable_ref="$2"
              shift 2
              ;;
            --limit)
              limit="$2"
              shift 2
              ;;
            --help|-h)
              cat <<'EOF'
Usage: nix run .#search-pkgs -- [--stable-ref REF] [--unstable-ref REF] [--limit N] QUERY...

Examples:
  nix run .#search-pkgs -- ghostty
  nix run .#search-pkgs -- --limit 10 lua language server
EOF
              exit 0
              ;;
            *)
              query_args+=("$1")
              shift
              ;;
          esac
        done

        if [ "''${#query_args[@]}" -eq 0 ]; then
          echo "search-pkgs: missing search query" >&2
          exit 2
        fi

        query="''${query_args[*]}"

        search_ref() {
          local label="$1"
          local ref="$2"
          local json

          printf '\n%s\n' "== $label =="
          printf '%s\n' "ref: $ref"

          if ! json="$(${pkgs.nix}/bin/nix --extra-experimental-features 'nix-command flakes' search --json "$ref" "$query" 2>/dev/null)"; then
            echo "search failed for $label" >&2
            return 1
          fi

          if [ "$(${pkgs.jq}/bin/jq 'length' <<<"$json")" -eq 0 ]; then
            echo "no matches"
            return 0
          fi

          ${pkgs.jq}/bin/jq -r --argjson limit "$limit" '
            to_entries
            | sort_by(.key)
            | .[:$limit]
            | .[]
            | [
                .key,
                (.value.version // "-"),
                (.value.description // "-" | gsub("[\r\n\t]+"; " "))
              ]
            | @tsv
          ' <<<"$json" | while IFS=$'\t' read -r attr version description; do
            printf '%-45s %-18s %s\n' "$attr" "$version" "$description"
          done
        }

        search_ref "unstable" "$unstable_ref"
        search_ref "stable" "$stable_ref"
      '')}/bin/search-pkgs";
    };
  mkHomeSwitchApp = system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      defaultTarget = "standalone-linux";
    in {
      type = "app";
      program = "${(pkgs.writeShellScriptBin "home-switch" ''
        set -euo pipefail

        target="${defaultTarget}"
        backup_ext="hm-backup-$(${pkgs.coreutils}/bin/date +%Y%m%d%H%M%S)"
        hm_args=()

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --target)
              target="$2"
              shift 2
              ;;
            -b|--backup-ext)
              backup_ext="$2"
              shift 2
              ;;
            --help|-h)
              cat <<'EOF'
Usage: nix run .#home-switch -- [--target HOME] [home-manager args...]

Defaults:
  x86_64-linux -> standalone-linux
  backup extension -> hm-backup-<timestamp>

Examples:
  nix run .#home-switch
  nix run .#home-switch -- --dry-run
  nix run .#home-switch -- --target standalone-linux --dry-run
  nix run .#home-switch -- --backup-ext my-backup --dry-run
EOF
              exit 0
              ;;
            *)
              hm_args+=("$1")
              shift
              ;;
          esac
        done

        # Fresh multi-user Nix installs may not have the default profile
        # directories initialized yet, which can trip up standalone
        # Home Manager. Touch the profile state first.
        ${pkgs.nix}/bin/nix profile list >/dev/null 2>&1 || true

        exec ${home-manager.packages.${system}.home-manager}/bin/home-manager \
          --extra-experimental-features "nix-command flakes" \
          switch \
          -b "$backup_ext" \
          --flake ${self}#$target \
          ''${hm_args[@]}
      '')}/bin/home-switch";
    };
  mkHomeNewsApp = system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      defaultTarget = "standalone-linux";
    in {
      type = "app";
      program = "${(pkgs.writeShellScriptBin "home-news" ''
        set -euo pipefail

        target="${defaultTarget}"
        hm_args=()

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --target)
              target="$2"
              shift 2
              ;;
            --help|-h)
              cat <<'EOF'
Usage: nix run .#home-news -- [--target HOME] [extra home-manager news args...]

Defaults:
  x86_64-linux -> standalone-linux

Examples:
  nix run .#home-news
  nix run .#home-news -- --show-trace
EOF
              exit 0
              ;;
            *)
              hm_args+=("$1")
              shift
              ;;
          esac
        done

        exec ${home-manager.packages.${system}.home-manager}/bin/home-manager \
          --extra-experimental-features "nix-command flakes" \
          --flake ${self}#$target \
          news \
          ''${hm_args[@]}
      '')}/bin/home-news";
    };
  mkUpdateApp = system:
    let
      pkgs = mkConfiguredPkgs system;
      linuxHomeSourcesUpdater = pkgs.writeShellApplication {
        name = "update-linux-home-sources";
        runtimeInputs = [
          pkgs.curl
          pkgs.git
          pkgs.jq
          pkgs.nix
          pkgs.python3
        ];
        text = ''
          set -euo pipefail

          repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
          cd "$repo_root"
          source_file="''${LINUX_HOME_MANAGER_FILE:-modules/linux/home-manager.nix}"

          garuda_sha="$(curl -fsSL 'https://gitlab.com/api/v4/projects/garuda-linux%2Fthemes-and-settings%2Fsettings%2Fgaruda-dr460nized/repository/commits?per_page=1' | jq -r '.[0].id')"
          beautyline_sha="$(curl -fsSL 'https://gitlab.com/api/v4/projects/garuda-linux%2Fthemes-and-settings%2Fartwork%2Fbeautyline/repository/commits?per_page=1' | jq -r '.[0].id')"
          candy_sha="$(curl -fsSL 'https://api.github.com/repos/EliverLara/candy-icons/commits?per_page=1' | jq -r '.[0].sha')"

          if [[ -z "$garuda_sha" || "$garuda_sha" == "null" ]]; then
            echo "Could not determine latest garuda-dr460nized commit" >&2
            exit 1
          fi
          if [[ -z "$beautyline_sha" || "$beautyline_sha" == "null" ]]; then
            echo "Could not determine latest beautyline commit" >&2
            exit 1
          fi
          if [[ -z "$candy_sha" || "$candy_sha" == "null" ]]; then
            echo "Could not determine latest candy-icons commit" >&2
            exit 1
          fi

          garuda_url="https://gitlab.com/garuda-linux/themes-and-settings/settings/garuda-dr460nized/-/archive/$garuda_sha/garuda-dr460nized-$garuda_sha.tar.gz"
          beautyline_url="https://gitlab.com/garuda-linux/themes-and-settings/artwork/beautyline/-/archive/$beautyline_sha/beautyline-$beautyline_sha.tar.gz"
          candy_url="https://github.com/EliverLara/candy-icons/archive/$candy_sha.tar.gz"

          prefetch_unpack() {
            local url="$1"
            local base32_hash
            base32_hash="$(nix-prefetch-url --unpack "$url")"
            nix hash convert --hash-algo sha256 --to sri "$base32_hash"
          }

          garuda_hash="$(prefetch_unpack "$garuda_url")"
          beautyline_hash="$(prefetch_unpack "$beautyline_url")"
          candy_hash="$(prefetch_unpack "$candy_url")"

          python3 - "$source_file" \
            "$garuda_url" "$garuda_hash" \
            "$beautyline_url" "$beautyline_hash" \
            "$candy_url" "$candy_hash" <<'PY'
import os
import re
import sys
import tempfile
from pathlib import Path

path = Path(sys.argv[1])
garuda_url, garuda_hash, beautyline_url, beautyline_hash, candy_url, candy_hash = sys.argv[2:8]
text = path.read_text()

def replace_once(pattern, replacement, label, flags=re.S):
    global text
    text, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"Could not update {label}; expected exactly one match, got {count}")

replace_once(
    r'(garudaDr460nized = pkgs\.fetchzip \{\s*url = )"[^"]+";(\s*hash = )"sha256-[^"]+";',
    rf'\g<1>"{garuda_url}";\g<2>"{garuda_hash}";',
    "garudaDr460nized source",
)
replace_once(
    r'(beautylineSrc = pkgs\.fetchzip \{\s*url = )"[^"]+";(\s*hash = )"sha256-[^"]+";',
    rf'\g<1>"{beautyline_url}";\g<2>"{beautyline_hash}";',
    "beautyline source",
)
replace_once(
    r'(candyIconsSrc = pkgs\.fetchzip \{\s*url = )"[^"]+";(\s*hash = )"sha256-[^"]+";',
    rf'\g<1>"{candy_url}";\g<2>"{candy_hash}";',
    "candy-icons source",
)

with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as tmp:
    tmp.write(text)
    tmp_path = Path(tmp.name)
os.replace(tmp_path, path)
PY

          echo "Linux Home Manager source pins are updated"
        '';
      };
      packageUpdater = name:
        let
          pkg = pkgs.${name} or null;
        in
        if pkg != null && pkg ? passthru && pkg.passthru ? updateScript
        then pkg.passthru.updateScript
        else null;
      validPackageUpdaterNames = nixpkgs.lib.filter
        (name: packageUpdater name != null)
        (localUpdaterNamesFor system);
      validUpdaterNames = validPackageUpdaterNames ++ [ "linux-home-sources" ];
      validUpdaterMap = nixpkgs.lib.concatMapStringsSep "\n"
        (name: "${name}\t${toString (packageUpdater name)}")
        validPackageUpdaterNames;
      validUpdaterNamesShell = nixpkgs.lib.concatMapStringsSep " " nixpkgs.lib.escapeShellArg validUpdaterNames;
      validUpdaterNamesText = nixpkgs.lib.concatStringsSep ", " validUpdaterNames;
      updaterCommands =
        nixpkgs.lib.concatMapStringsSep "\n"
          (name:
            let script = packageUpdater name;
            in nixpkgs.lib.optionalString (script != null) ''
              run_local_updater ${nixpkgs.lib.escapeShellArg name} ${nixpkgs.lib.escapeShellArg (toString script)}
            '')
          validPackageUpdaterNames
        + ''
          run_local_updater linux-home-sources ${nixpkgs.lib.escapeShellArg (toString (nixpkgs.lib.getExe linuxHomeSourcesUpdater))}
        '';
    in {
      type = "app";
      program = "${(pkgs.writeShellScriptBin "update" ''
        set -euo pipefail

        repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd)"
        cd "$repo_root"

        run_flake_update=1
        run_local_updates=1
        selected_packages=()
        flake_args=()
        valid_updaters=(${validUpdaterNamesShell})

        usage() {
          cat <<'EOF'
Usage: nix run .#update -- [options] [flake-input...]

Updates flake inputs and repo-local source pins.

Options:
  --flake-only       Run only nix flake update
  --local-only       Run only local package updaters
  --skip-flake       Do not run nix flake update
  --skip-local       Do not run local package updaters
  --package NAME     Run only the named local package updater; repeatable
  -h, --help         Show this help

Examples:
  nix run .#update
  nix run .#update -- nixpkgs home-manager
  nix run .#update -- --local-only --package linux-home-sources
EOF
        }

        valid_updater() {
          local name="$1"
          local valid
          for valid in "''${valid_updaters[@]}"; do
            if [ "$valid" = "$name" ]; then
              return 0
            fi
          done
          return 1
        }

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --flake-only)
              run_local_updates=0
              shift
              ;;
            --local-only)
              run_flake_update=0
              shift
              ;;
            --skip-flake)
              run_flake_update=0
              shift
              ;;
            --skip-local)
              run_local_updates=0
              shift
              ;;
            --package)
              if [ "$#" -lt 2 ] || [[ "$2" == --* ]]; then
                echo "update: --package requires a local updater name" >&2
                usage >&2
                exit 2
              fi
              selected_packages+=("$2")
              shift 2
              ;;
            --help|-h)
              usage
              exit 0
              ;;
            *)
              flake_args+=("$1")
              shift
              ;;
          esac
        done

        for selected in "''${selected_packages[@]}"; do
          if ! valid_updater "$selected"; then
            echo "update: unknown local updater: $selected" >&2
            echo "valid local updaters: ${validUpdaterNamesText}" >&2
            exit 2
          fi
        done

        if [ "$run_flake_update" -eq 1 ]; then
          ${pkgs.nix}/bin/nix flake update "''${flake_args[@]}"
        fi

        package_selected() {
          local name="$1"
          if [ "''${#selected_packages[@]}" -eq 0 ]; then
            return 0
          fi
          local selected
          for selected in "''${selected_packages[@]}"; do
            if [ "$selected" = "$name" ]; then
              return 0
            fi
          done
          return 1
        }

        run_local_updater() {
          local name="$1"
          local script="$2"
          if ! package_selected "$name"; then
            return 0
          fi
          printf '\n== Updating local package: %s ==\n' "$name"
          "$script"
        }

        if [ "$run_local_updates" -eq 1 ]; then
          ${updaterCommands}
        fi
      '')}/bin/update";
    };
  mkLinuxApps = system:
    let
      nhPkg = inputs.nh.packages.${system}.default or null;
    in {
      "build" = mkApp "build" system;
      "home-news" = mkHomeNewsApp system;
      "home-switch" = mkHomeSwitchApp system;
      "search-pkgs" = mkSearchPkgsApp system;
      "update" = mkUpdateApp system;
      "build-switch" = mkApp "build-switch" system;
      "clean" = mkApp "clean" system;
    } // lib.optionalAttrs (nhPkg != null) {
      "nh" = {
        type = "app";
        program = "${nhPkg}/bin/nh";
      };
    };
  mkDarwinApps = system:
    {
      "build" = mkApp "build" system;
      "search-pkgs" = mkSearchPkgsApp system;
      "build-switch" = mkApp "build-switch" system;
      "clean" = mkApp "clean" system;
      "update" = mkUpdateApp system;
    };
in {
  perSystem = { system, ... }: {
    apps = if system == "aarch64-darwin" then mkDarwinApps system else mkLinuxApps system;
  };
}
