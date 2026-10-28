# Ghostty 1.4.0 for Darwin.
#
# nixpkgs' ghostty-bin is still 1.3.1, while upstream published 1.4.0 on
# 2026-10-27. The Darwin package is a single signed DMG whose build recipe
# never changed between the two releases, so the update is the version and the
# DMG hash. Delete this override and use `ghostty-bin` directly once nixpkgs
# carries 1.4.0.
{ ghostty-bin, fetchurl }:

ghostty-bin.overrideAttrs (_old: {
  version = "1.4.0";
  src = fetchurl {
    url = "https://release.files.ghostty.org/1.4.0/Ghostty.dmg";
    hash = "sha256-OgIHXb0kMY13hCavQd7lUH1T7MRXjt6WkS7Jzm0Y0+g=";
  };
})
