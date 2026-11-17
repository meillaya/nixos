# Helium (AppImage) wrapped so the browser UI resolves the host's Nix-store
# fonts instead of the AppImage's bundled copies.
#
# Helium ships as an AppImage (appimageTools.wrapType2). The wrapType2 output is
# a bubblewrap script at `$out/bin/helium` that mounts an FHS rootfs containing
# the AppImage's bundled `libfontconfig.so.1` / `libfreetype.so.6`. Those bundled
# libs only see the AppImage's own fontconfig tree, so the browser UI (URL bar,
# bookmarks, tab strip) and any page using `system-ui` fall back to Chromium's
# hard-coded Roboto / DejaVu Sans instead of the Nix-store fonts installed on
# the host. `chrome://settings/appearance` cannot fix this because the bundled
# fontconfig never resolves the host fonts.
#
# Wrap the launcher a second time so `LD_LIBRARY_PATH` puts the host's
# fontconfig + freetype ahead of the AppImage's bundled copies in the dynamic
# linker's search path. bwrap propagates the env into the sandbox.
#
# The host fontconfig library is not enough on a foreign distribution. The
# sandbox binds the host `/etc/fonts` but replaces `/usr`, so a distro
# `conf.d` whose entries point into `/usr/share/fontconfig` resolves no
# targets, and the user config that adds the Nix profile font trees is never
# loaded. Fontconfig then falls back to whatever font it can find; on CachyOS
# that is an icon font, which renders every page in the wrong face. Point
# fontconfig at one generated file instead: the stock fontconfig rules minus
# the user and local includes, the profile font directories, and Fira Sans as
# the sans-serif answer to match the rest of the desktop.

{ lib, makeWrapper, runCommand, writeText, fontconfig, freetype, helium }:

let
  # The stock fontconfig rules, minus the two files that pull in host-local
  # user and distro config. Those two are the ones that break inside the bwrap
  # rootfs.
  stockConfD = runCommand "helium-fontconfig-conf.d" { } ''
    mkdir -p $out
    for config in ${fontconfig.out}/etc/fonts/conf.d/*; do
      case "$(basename "$config")" in
        50-user.conf | 51-local.conf) continue ;;
      esac
      ln -s "$config" "$out/$(basename "$config")"
    done
  '';

  fontsConf = writeText "helium-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <cachedir prefix="xdg">fontconfig</cachedir>
      <dir>~/.nix-profile/share/fonts</dir>
      <dir>~/.nix-profile/lib/X11/fonts</dir>
      <dir>/nix/var/nix/profiles/default/share/fonts</dir>
      <dir>/nix/var/nix/profiles/default/lib/X11/fonts</dir>
      <dir>/run/current-system/sw/share/fonts</dir>
      <dir>/run/current-system/sw/lib/X11/fonts</dir>
      <dir>/run/system-manager/sw/share/fonts</dir>
      <dir>/run/system-manager/sw/lib/X11/fonts</dir>
      <dir>~/.local/share/fonts</dir>
      <dir>~/.fonts</dir>
      <dir>/usr/share/fonts</dir>
      <dir>/usr/local/share/fonts</dir>
      <include ignore_missing="yes">${stockConfD}</include>
      <match target="pattern">
        <test name="family"><string>sans-serif</string></test>
        <edit name="family" mode="prepend" binding="strong"><string>Fira Sans</string></edit>
      </match>
      <match target="pattern">
        <test name="family"><string>system-ui</string></test>
        <edit name="family" mode="prepend" binding="strong"><string>Fira Sans</string></edit>
      </match>
    </fontconfig>
  '';
in

helium.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ makeWrapper ];
  # The upstream wrapType2 derivation is a runCommand, so its genericBuild
  # early-returns after sourcing `buildCommand` and bypasses every standard
  # phase hook (including `postInstall`). Append the wrap to `buildCommand`
  # itself so it actually runs.
  buildCommand = (old.buildCommand or "") + ''
    wrapProgram $out/bin/helium \
      --prefix LD_LIBRARY_PATH : "${fontconfig.lib}/lib:${freetype}/lib" \
      --set FONTCONFIG_FILE "${fontsConf}"
  '';
})
