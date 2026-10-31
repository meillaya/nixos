{
  lib,
  buildNpmPackage,
  makeWrapper,
  nodejs_22,
  browser ? null,
}:

let
  # Optional browser path baked into the wrapper. The CLI never bundles a
  # browser; it drives Chrome, Chromium, Edge, or Firefox from the host.
  browserArgs =
    lib.optionalString (browser != null)
      "--set EXCALIDRAW_BROWSER_PATH ${lib.escapeShellArg browser}";
in
buildNpmPackage rec {
  pname = "excalidraw-cli";
  version = "0.2.0";

  # package.json + package-lock.json pin @excalidraw/cli 0.2.0 and its one
  # runtime dependency, playwright-core 1.63.0. Regenerate the lock with
  # `npm install --package-lock-only` after a version bump, then refresh
  # npmDepsHash with `nix run nixpkgs#prefetch-npm-deps -- npm/package-lock.json`.
  src = ./npm;
  npmDepsHash = "sha256-0ly6DgqueMAggkGI+GDw3nAp7Sl936ygPAEGZIs0knw=";

  nodejs = nodejs_22;
  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  # The upstream tarball is prebuilt: dist/main.js plus its node_modules.
  # npmInstallHook places the package at $out/lib/node_modules/<name>; expose
  # the CLI through node so no /usr/bin/env lookup is needed.
  postInstall = ''
    makeWrapper ${nodejs_22}/bin/node $out/bin/excalidraw \
      --add-flags "$out/lib/node_modules/${pname}/node_modules/@excalidraw/cli/dist/main.js" \
      ${browserArgs}
  '';

  meta = {
    description = "Excalidraw CLI, packaged for Nix";
    homepage = "https://github.com/excalidraw/cli";
    license = lib.licenses.mit;
    mainProgram = "excalidraw";
    platforms = lib.platforms.unix;
  };
}
