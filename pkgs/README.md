# Custom Packages

Derivations for tools not (yet) in nixpkgs. Each file is a self-contained
package expression that gets imported into the relevant package list.

## When to use this

- A tool's installer is `curl | sh` and dumps a binary somewhere ad-hoc
- The tool is in nixpkgs but you need a newer version than the current pin
- The tool is not in nixpkgs at all

**Prefer `pkgs.<name>` from nixpkgs first.** Only add a custom derivation
when nixpkgs doesn't have it or the version lag matters.

## How to add a tool

1. Copy `_template.nix` → `<tool-name>.nix`
2. Fill in `pname`, `version`, `src.url`, and `hash`
3. Get the real hash — use a fake one first and nix will report it:
   ```
   hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
   ```
4. Wire it into the package list:
   ```nix
   # In modules/shared/packages.nix (cross-platform)
   # or modules/linux/packages.nix (Linux-only):
   (pkgs.callPackage ../../pkgs/<tool-name>.nix { })
   ```
5. Apply: `nix run .#home-switch`

## Patterns

### Prebuilt binary (most common)
See `_template.nix`. Uses `fetchzip` + `autoPatchelfHook`.

### Shell script
```nix
{ writeShellScriptBin, curl, jq }:
writeShellScriptBin "my-tool" ''
  ${curl}/bin/curl -s https://api.example.com/thing | ${jq}/bin/jq .
''
```

### Single file (no archive)
```nix
{ stdenvNoCC, fetchurl }:
stdenvNoCC.mkDerivation {
  pname = "some-script";
  version = "1.0";
  src = fetchurl {
    url = "https://example.com/tool.sh";
    hash = "sha256-...";
  };
  dontUnpack = true;
  installPhase = ''
    install -Dm755 $src $out/bin/some-script
  '';
}
```

## Updating versions

Bump `version` and `hash` in the derivation, then `nix run .#home-switch`.
Nix will fail with the correct hash if the old one doesn't match.
