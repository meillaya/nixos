# Helium (AppImage) wrapped so the browser UI resolves the host's Nix-store
# fonts instead of the AppImage's bundled copies.
#
# Helium ships as an AppImage (appimageTools.wrapType2). The wrapType2 output
# is a bubblewrap script at `$out/bin/helium` that mounts an FHS rootfs
# containing the AppImage's bundled `libfontconfig.so.1` / `libfreetype.so.6`.
# Those bundled libs only see the AppImage's own fontconfig tree, so the
# browser UI (URL bar, bookmarks, tab strip) and any page using `system-ui`
# fall back to Chromium's hard-coded Roboto / DejaVu Sans instead of the
# Nix-store fonts installed on the host. `chrome://settings/appearance`
# cannot fix this because the bundled fontconfig never resolves the host
# fonts.
#
# Wrap the launcher a second time so `LD_LIBRARY_PATH` puts the host's
# fontconfig + freetype ahead of the AppImage's bundled copies in the dynamic
# linker's search path. bwrap propagates the env into the sandbox, and the
# system libs have Nix-aware defaults that pick up fonts under `/nix/store`.
# `FONTCONFIG_FILE` is intentionally left alone because the system fontconfig
# already knows where to look.

{ lib, makeWrapper, fontconfig, freetype, helium }:

helium.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ makeWrapper ];
  # The upstream wrapType2 derivation is a runCommand, so its genericBuild
  # early-returns after sourcing `buildCommand` and bypasses every standard
  # phase hook (including `postInstall`). Append the wrap to `buildCommand`
  # itself so it actually runs.
  buildCommand = (old.buildCommand or "") + ''
    wrapProgram $out/bin/helium \
      --prefix LD_LIBRARY_PATH : "${fontconfig.lib}/lib:${freetype}/lib"
  '';
})
