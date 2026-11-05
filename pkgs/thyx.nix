# Thyx SDDM theme, pinned to the upstream v1.1.0 tag.
#
# SDDM reads the theme directory from ThemeDir, so the package installs the
# whole theme tree under $out/share/sddm/themes/thyx instead of copying it into
# /usr/share. The selected preset replaces theme.conf so the greeter starts on
# that preset; the presets directory stays installed for later changes.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  preset ? "blush",
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "thyx";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "rccyx";
    repo = "thyx";
    rev = "v${finalAttrs.version}";
    hash = "sha256-JB132Bwzq6UpXP5y6slNAYE00q8qJdyTRUzaiUpGbqw=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    theme="$out/share/sddm/themes/thyx"
    fonts="$out/share/fonts/truetype/thyx"
    licenses="$out/share/licenses/thyx"

    mkdir -p "$theme" "$fonts" "$licenses"

    install -m0644 metadata.desktop "$theme/metadata.desktop"
    install -m0644 "presets/${preset}.conf" "$theme/theme.conf"
    cp -r backgrounds icons presets src "$theme/"
    install -m0644 LICENSE "$licenses/LICENSE"
    install -m0644 fonts/OFL.txt "$licenses/OFL.txt"
    install -m0644 fonts/*.ttf -t "$fonts"

    runHook postInstall
  '';

  meta = {
    description = "Thyx SDDM theme prepared with the ${preset} preset";
    homepage = "https://github.com/rccyx/thyx";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
