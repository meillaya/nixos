# Vendored from nixpkgs nixos-26.05 (pkgs/by-name/sw/sweet/package.nix).
#
# Upstream removed sweet (and five sibling GTK themes) from master because it
# propagated gtk-engine-murrine, which was itself removed as unmaintained
# (nixpkgs issue #549887). The theme is GTK3/GTK4-first and does not need the
# GTK2 engine to build or render; the only change vs upstream is dropping that
# propagation. If upstream restores the theme, delete this file and use
# pkgs.sweet again.
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  colorVariants ? [ ], # default: install all variants
}:

let
  pname = "sweet";
  colorVariantList = [
    "Sweet-Ambar-Blue-Dark-v40"
    "Sweet-Ambar-Blue-Dark"
    "Sweet-Ambar-Blue-v40"
    "Sweet-Ambar-Blue"
    "Sweet-Ambar-v40"
    "Sweet-Ambar"
    "Sweet-Dark-v40"
    "Sweet-Dark"
    "Sweet-mars-v40"
    "Sweet-mars"
    "Sweet-v40"
    "Sweet"
  ];

in
lib.checkListOfEnum "${pname}: color variants" colorVariantList colorVariants

  stdenvNoCC.mkDerivation
  (finalAttrs: {
    inherit pname;
    version = "6.0";

    srcs = [
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-Ambar-Blue-Dark-v40.tar.xz";
        hash = "sha256-LufK9MexE6YMuVniyfcNNaPfVLBMHnNmWBBNnGA2nUo=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-Ambar-Blue-Dark.tar.xz";
        hash = "sha256-J0YOADP4FXKYMl/Nn70clD3h7Y5LtlTfWV9VLsWL9yo=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-Ambar-Blue-v40.tar.xz";
        hash = "sha256-HH9oZQ+F1nFhIJyP9d9W2CL+mA0bolq5GiNQtKQgrZk=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-Ambar-Blue.tar.xz";
        hash = "sha256-2dcryd5Zj+Iu3R4jR++uJtyToGNoa1LtTpN1G6+kBRw=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-Ambar-v40.tar.xz";
        hash = "sha256-mpShu1fmBajl/wzlnu9zBWkskMlza5nEVS3u8Sh3b7s=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-Ambar.tar.xz";
        hash = "sha256-wcbJW6MUctGSM8GW1ouLvUCmdcDHQkjTw9h0foRBgTg=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-Dark-v40.tar.xz";
        hash = "sha256-aYPjnOEZMN9mPvnhK3eoCm1ybUxKPqPSoOL+kwsZsG4=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-Dark.tar.xz";
        hash = "sha256-Ej9p7/txrMhGUCyDTAEQHIS/pi92pfLrCV1L4HxWdZk=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-mars-v40.tar.xz";
        hash = "sha256-AKTNa6FHlPr1ZqlK5QYZzXRiPb5Nmzw2lTSNcWAtMAg=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-mars.tar.xz";
        hash = "sha256-bCL/DqiQGiHR24aaPtPyJKAkk8X+DyMxYeYuFJBuK6Y=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet-v40.tar.xz";
        hash = "sha256-1kHWoK9r3mRYIkizekVVYyFpWXU78BExKuNUsRB4uv4=";
      })
      (fetchurl {
        url = "https://github.com/EliverLara/Sweet/releases/download/v${finalAttrs.version}/Sweet.tar.xz";
        hash = "sha256-WzsquuUreT7b6TA6qGSYqGVrVWlIdQjlIdqWGMNJFpo=";
      })
    ];

    nativeBuildInputs = [ unzip ];

    # gtk-engine-murrine deliberately dropped: upstream removed it (unmaintained)
    # and the theme renders GTK3/GTK4 without it. GTK2 apps fall back.

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/themes/
      cp -r ${
        lib.concatStringsSep " " (if colorVariants != [ ] then colorVariants else colorVariantList)
      } $out/share/themes/
      runHook postInstall
    '';

    meta = {
      description = "Light and dark colorful Gtk3.20+ theme (vendored: dropped upstream over gtk-engine-murrine)";
      homepage = "https://github.com/EliverLara/Sweet";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.unix;
    };
  })
