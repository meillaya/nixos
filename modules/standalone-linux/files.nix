{ pkgs }:
let
  ghosttyConfig = builtins.replaceStrings
    [ "@NU_COMMAND@" ]
    [ "${pkgs.nushell}/bin/nu --login" ]
    (builtins.readFile ./config/ghostty/config.ghostty);
in
{
  ".config/niri/config.kdl".text = builtins.readFile ../linux/config/niri/config.kdl;

  ".config/calibre/gui.json".source = ./config/calibre/gui.json;
  ".config/calibre/tweaks.json".source = ./config/calibre/tweaks.json;
  ".config/calibre/save_to_disk.py.json".source = ./config/calibre/save_to_disk.py.json;
  ".config/calibre/metadata_sources/global.json".source = ./config/calibre-metadata-sources-global.json;
  ".config/calibre/conversion/page_setup.py".source = ./config/calibre/conversion/page_setup.py;
  ".config/zed/settings.json".source = ./config/zed/settings.json;
  ".config/ghostty/config" = {
    text = ghosttyConfig;
    force = true;
  };
  ".config/ghostty/config.ghostty".text = ghosttyConfig;
  ".config/fastfetch/config.jsonc".source = ../shared/config/fastfetch/config.jsonc;
  ".config/fastfetch/snoopy-mugiwara.png".source = ../shared/config/fastfetch/snoopy-mugiwara.png;

  # Expose the nix JDK where IDE toolchain scanners look: IntelliJ/Android
  # Studio scan ~/.jdks regardless of the launching environment, so
  # GUI-launched Studio finds the Java 21 toolchain without shell env.
  ".jdks/openjdk-21".source = "${pkgs.openjdk.home}";
}
