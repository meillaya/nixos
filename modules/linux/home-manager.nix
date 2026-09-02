{ config, pkgs, lib, ... }:

let
  garudaDr460nized = pkgs.fetchzip {
    url = "https://gitlab.com/garuda-linux/themes-and-settings/settings/garuda-dr460nized/-/archive/35eb3abbc534f4046257c43ad9e05a9c010235cf/garuda-dr460nized-35eb3abbc534f4046257c43ad9e05a9c010235cf.tar.gz";
    hash = "sha256-4kRU4h3WRuVjixhK5B/x19bIxtHc9vcfbv5QPjFMBfc=";
  };

  beautylineSrc = pkgs.fetchzip {
    url = "https://gitlab.com/garuda-linux/themes-and-settings/artwork/beautyline/-/archive/cb19ed82a10c49e035a68000860c9a49fea79ff2/beautyline-cb19ed82a10c49e035a68000860c9a49fea79ff2.tar.gz";
    hash = "sha256-pjpT0zJZ03RAH4mz5gJgJRzSAJ2mI23mMlx45JQiOnY=";
  };

  candyIconsSrc = pkgs.fetchzip {
    url = "https://github.com/EliverLara/candy-icons/archive/83512fbcadcb7e1015ebbe1729a1894946b021be.tar.gz";
    hash = "sha256-TzovzmfrUuaSrtpKCQxyXcih7cKSBhBtMpZLVwY/ScA=";
  };

  # Vendored: upstream removed the theme over gtk-engine-murrine (#549887)
  sweet = pkgs.callPackage ../../pkgs/sweet.nix { };

  dolphinEnv = "QT_STYLE_OVERRIDE=kvantum QT_QUICK_CONTROLS_STYLE=org.kde.desktop XDG_MENU_PREFIX=plasma-";
  dolphinBin = "${pkgs.kdePackages.dolphin}/bin/dolphin";
  okularBin = "${pkgs.kdePackages.okular}/bin/okular";
  arkBin = "${pkgs.kdePackages.ark}/bin/ark";

  archiveMimeTypes = [
    "application/zip"
    "application/x-7z-compressed"
    "application/vnd.rar"
    "application/x-rar"
    "application/x-tar"
    "application/x-compressed-tar"
    "application/x-bzip-compressed-tar"
    "application/x-xz-compressed-tar"
    "application/x-zstd-compressed-tar"
    "application/gzip"
    "application/x-bzip"
    "application/x-xz"
    "application/zstd"
  ];

  arkDesktopMimeTypes = archiveMimeTypes ++ [
    "application/x-archive"
    "application/x-arj"
    "application/x-bzip2"
    "application/x-cbr"
    "application/x-cbz"
    "application/x-cd-image"
    "application/x-compress"
    "application/x-cpio"
    "application/x-deb"
    "application/x-gzip"
    "application/x-java-archive"
    "application/x-lrzip"
    "application/x-lz4"
    "application/x-lzip"
    "application/x-lzma"
    "application/x-rpm"
    "application/x-source-rpm"
    "application/x-tzo"
    "application/x-xar"
    "application/x-zoo"
    "application/x-zstd"
  ];

  mimeDefaults = {
    "inode/directory" = "org.kde.dolphin.desktop";
    "application/x-directory" = "org.kde.dolphin.desktop";
    "application/x-gnome-saved-search" = "org.kde.dolphin.desktop";
    "x-scheme-handler/file" = "org.kde.dolphin.desktop";

    "application/zip" = "org.kde.ark.desktop";
    "application/x-7z-compressed" = "org.kde.ark.desktop";
    "application/vnd.rar" = "org.kde.ark.desktop";
    "application/x-rar" = "org.kde.ark.desktop";
    "application/x-tar" = "org.kde.ark.desktop";
    "application/x-compressed-tar" = "org.kde.ark.desktop";
    "application/x-bzip-compressed-tar" = "org.kde.ark.desktop";
    "application/x-xz-compressed-tar" = "org.kde.ark.desktop";
    "application/x-zstd-compressed-tar" = "org.kde.ark.desktop";
    "application/gzip" = "org.kde.ark.desktop";
    "application/x-bzip" = "org.kde.ark.desktop";
    "application/x-xz" = "org.kde.ark.desktop";
    "application/zstd" = "org.kde.ark.desktop";

    "application/pdf" = "okularApplication_pdf.desktop";
    "application/x-gzpdf" = "okularApplication_pdf.desktop";
    "application/x-bzpdf" = "okularApplication_pdf.desktop";
    "text/html" = "zen-beta.desktop";
    "application/xhtml+xml" = "zen-beta.desktop";
    "x-scheme-handler/http" = "zen-beta.desktop";
    "x-scheme-handler/https" = "zen-beta.desktop";
    "text/markdown" = "okularApplication_md.desktop";
    "application/epub+zip" = "okularApplication_epub.desktop";
    "application/vnd.comicbook+zip" = "okularApplication_comicbook.desktop";
    "application/vnd.comicbook-rar" = "okularApplication_comicbook.desktop";
    "image/png" = "okularApplication_kimgio.desktop";
    "image/jpeg" = "okularApplication_kimgio.desktop";
    "image/webp" = "okularApplication_kimgio.desktop";
    "image/gif" = "okularApplication_kimgio.desktop";
    "image/tiff" = "okularApplication_tiff.desktop";

    "text/plain" = "dev.zed.Zed.desktop";
    "video/mp4" = "mpv.desktop";
    "video/x-matroska" = "mpv.desktop";
    "video/webm" = "mpv.desktop";
  };

  mimeAssociations = {
    "inode/directory" = [ "org.kde.dolphin.desktop" "org.gnome.Nautilus.desktop" "thunar.desktop" "yazi.desktop" ];
    "application/x-directory" = [ "org.kde.dolphin.desktop" ];
    "application/x-gnome-saved-search" = [ "org.kde.dolphin.desktop" ];
    "x-scheme-handler/file" = [ "org.kde.dolphin.desktop" ];

    "application/zip" = [ "org.kde.ark.desktop" ];
    "application/x-7z-compressed" = [ "org.kde.ark.desktop" ];
    "application/vnd.rar" = [ "org.kde.ark.desktop" ];
    "application/x-rar" = [ "org.kde.ark.desktop" ];
    "application/x-tar" = [ "org.kde.ark.desktop" ];
    "application/x-compressed-tar" = [ "org.kde.ark.desktop" ];
    "application/x-bzip-compressed-tar" = [ "org.kde.ark.desktop" ];
    "application/x-xz-compressed-tar" = [ "org.kde.ark.desktop" ];
    "application/x-zstd-compressed-tar" = [ "org.kde.ark.desktop" ];
    "application/gzip" = [ "org.kde.ark.desktop" ];
    "application/x-bzip" = [ "org.kde.ark.desktop" ];
    "application/x-xz" = [ "org.kde.ark.desktop" ];
    "application/zstd" = [ "org.kde.ark.desktop" ];

    "application/pdf" = [ "okularApplication_pdf.desktop" "org.kde.okular.desktop" "zen.desktop" ];
    "application/x-gzpdf" = [ "okularApplication_pdf.desktop" "org.kde.okular.desktop" ];
    "application/x-bzpdf" = [ "okularApplication_pdf.desktop" "org.kde.okular.desktop" ];
    "text/html" = [ "zen-beta.desktop" ];
    "application/xhtml+xml" = [ "zen-beta.desktop" ];
    "x-scheme-handler/http" = [ "zen-beta.desktop" ];
    "x-scheme-handler/https" = [ "zen-beta.desktop" ];
    "text/markdown" = [ "okularApplication_md.desktop" "dev.zed.Zed.desktop" "micro.desktop" ];
    "application/epub+zip" = [ "okularApplication_epub.desktop" "calibre-ebook-viewer.desktop" "calibre-gui.desktop" ];
    "application/vnd.comicbook+zip" = [ "okularApplication_comicbook.desktop" ];
    "application/vnd.comicbook-rar" = [ "okularApplication_comicbook.desktop" ];
    "image/png" = [ "okularApplication_kimgio.desktop" "gimp.desktop" ];
    "image/jpeg" = [ "okularApplication_kimgio.desktop" "gimp.desktop" ];
    "image/webp" = [ "okularApplication_kimgio.desktop" "gimp.desktop" ];
    "image/gif" = [ "okularApplication_kimgio.desktop" "gimp.desktop" ];
    "image/tiff" = [ "okularApplication_tiff.desktop" "okularApplication_kimgio.desktop" "gimp.desktop" ];

    "text/plain" = [ "dev.zed.Zed.desktop" "micro.desktop" "okularApplication_txt.desktop" ];
    "video/mp4" = [ "mpv.desktop" ];
    "video/x-matroska" = [ "mpv.desktop" ];
    "video/webm" = [ "mpv.desktop" ];
  };

  mimeAppsText = ''
    [Default Applications]
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (mime: desktop: "${mime}=${desktop}") mimeDefaults)}

    [Added Associations]
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (mime: desktops: "${mime}=${lib.concatStringsSep ";" desktops};") mimeAssociations)}
  '';

  okularDesktop = mimeTypes: ''
    [Desktop Entry]
    Type=Application
    Name=Okular
    GenericName=Document Viewer
    Exec=env ${dolphinEnv} ${okularBin} %U
    Icon=okular
    Terminal=false
    NoDisplay=true
    Categories=Qt;KDE;Graphics;Office;Viewer;
    MimeType=${lib.concatStringsSep ";" mimeTypes};
  '';

  dolphinDesktop = ''
    [Desktop Entry]
    Type=Application
    Name=Dolphin
    GenericName=File Manager
    Comment=Manage your files
    Exec=env ${dolphinEnv} ${dolphinBin} %u
    Icon=org.kde.dolphin
    Terminal=false
    Categories=Qt;KDE;System;FileTools;FileManager;
    MimeType=inode/directory;
    InitialPreference=10
  '';

  arkDesktop = ''
    [Desktop Entry]
    Type=Application
    Name=Ark
    GenericName=Archive Manager
    Comment=Work with file archives
    Exec=env ${dolphinEnv} ${arkBin} %U
    Icon=ark
    Terminal=false
    Categories=Qt;KDE;Utility;Archiving;Compression;
    MimeType=${lib.concatStringsSep ";" arkDesktopMimeTypes};
  '';

  obsStudioDesktop = ''
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=OBS Studio
    GenericName=Streaming/Recording Software
    Comment=Free and Open Source Streaming/Recording Software
    Exec=env OBS_QPA_PLATFORM=wayland obs
    Icon=com.obsproject.Studio
    Terminal=false
    Categories=AudioVideo;Recorder;
    StartupNotify=true
    StartupWMClass=obs
  '';

  applicationsMenu = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN" "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
      <Include>
        <All/>
      </Include>
    </Menu>
  '';

  portalConfig = ''
    [preferred]
    default=gnome;gtk;
    org.freedesktop.impl.portal.ScreenCast=gnome;
    org.freedesktop.impl.portal.RemoteDesktop=gnome;
    org.freedesktop.impl.portal.Screenshot=gnome;
    org.freedesktop.impl.portal.FileChooser=kde-niri;gtk;
    org.freedesktop.impl.portal.AppChooser=kde-niri;gtk;
    org.freedesktop.impl.portal.Settings=kde-niri;gtk;
    org.freedesktop.impl.portal.Access=gtk;
    org.freedesktop.impl.portal.Notification=gtk;
    org.freedesktop.impl.portal.Secret=gnome-keyring;
  '';

  kdeNiriPortal = ''
    [portal]
    DBusName=org.freedesktop.impl.portal.desktop.kde
    Interfaces=org.freedesktop.impl.portal.FileChooser;org.freedesktop.impl.portal.AppChooser;org.freedesktop.impl.portal.Settings
    UseIn=niri
  '';

  gtkSettings = ''
    [Settings]
    gtk-theme-name=Sweet-Dark
    gtk-icon-theme-name=BeautyLine
    gtk-font-name=Fira Sans 10
    gtk-cursor-theme-name=Sweet-cursors
    gtk-application-prefer-dark-theme=true
  '';

  gtkFileChooserSettings = ''
    [Filechooser Settings]
    LocationMode=path-bar
    ShowHidden=false
    ShowSizeColumn=true
    GeometryWidth=1100
    GeometryHeight=720
    SortColumn=name
    SortOrder=ascending
    StartupMode=cwd
  '';

  konsoleRc = ''
    [Desktop Entry]
    DefaultProfile=Garuda.profile

    [KonsoleWindow]
    SaveGeometryOnExit=true
    ShowMenuBarByDefault=false

    [MainWindow]
    MenuBar=Disabled
    RestorePositionForNextInstance=true
    StatusBar=Disabled
  '';

  konsoleProfile = ''
    [Appearance]
    ColorScheme=Sweet
    Font=FiraCode Nerd Font Mono,12,-1,5,50,0,0,0,0,0
    UseFontLineChararacters=true
    UseFontLineCharacters=true

    [Cursor Options]
    CursorShape=2
    CustomCursorColor=255,0,0
    UseCustomCursorColor=true

    [General]
    Command=${pkgs.nushell}/bin/nu --login
    Name=Garuda
    Parent=FALLBACK/
    TerminalColumns=110
    TerminalRows=30

    [Interaction Options]
    AutoCopySelectedText=true
    TrimLeadingSpacesInSelectedText=true
    TrimTrailingSpacesInSelectedText=true
    UnderlineFilesEnabled=true

    [Keyboard]
    KeyBindings=default

    [Scrolling]
    HistoryMode=1

    [Terminal Features]
    BlinkingCursorEnabled=true
  '';

  konsoleSweetColorScheme = ''
    [Background]
    Color=22,25,37

    [BackgroundFaint]
    Color=22,25,37

    [BackgroundIntense]
    Color=105,115,136

    [Color0]
    Color=105,115,136

    [Color0Faint]
    Color=105,115,136

    [Color0Intense]
    Color=105,115,136

    [Color1]
    Color=237,37,78

    [Color1Faint]
    Color=237,37,78

    [Color1Intense]
    Color=237,37,78

    [Color2]
    Color=113,247,159

    [Color2Faint]
    Color=113,247,159

    [Color2Intense]
    Color=113,247,159

    [Color3]
    Color=249,220,92

    [Color3Faint]
    Color=249,220,92

    [Color3Intense]
    Color=249,220,92

    [Color4]
    Color=124,183,255

    [Color4Faint]
    Color=124,183,255

    [Color4Intense]
    Color=124,183,255

    [Color5]
    Color=199,77,237

    [Color5Faint]
    Color=199,77,237

    [Color5Intense]
    Color=199,77,237

    [Color6]
    Color=0,193,228

    [Color6Faint]
    Color=0,193,228

    [Color6Intense]
    Color=0,193,228

    [Color7]
    Color=220,223,228

    [Color7Faint]
    Color=220,223,228

    [Color7Intense]
    Color=220,223,228

    [Foreground]
    Color=195,199,209

    [ForegroundFaint]
    Color=92,99,112

    [ForegroundIntense]
    Color=130,137,151

    [General]
    Blur=true
    ColorRandomization=false
    Description=Sweet
    Opacity=0.65
    Wallpaper=
  '';

  serviceMenu = ''
    [Desktop Entry]
    Type=Service
    Name=Dr460nized Dolphin Actions
    ServiceTypes=KonqPopupMenu/Plugin
    X-KDE-ServiceTypes=KonqPopupMenu/Plugin
    MimeType=inode/directory;
    Actions=OpenDr460nizedDolphin;OpenAdminDolphin;CopyPath;
    X-KDE-Priority=TopLevel

    [Desktop Action OpenDr460nizedDolphin]
    Name=Open in Dr460nized Dolphin
    Icon=org.kde.dolphin
    Exec=env ${dolphinEnv} ${dolphinBin} %U

    [Desktop Action OpenAdminDolphin]
    Name=Open as Administrator
    Icon=system-file-manager
    Exec=${dolphinBin} --admin %U
  '';

  arkServiceMenu = ''
    [Desktop Entry]
    Type=Service
    Name=Ark Archive Actions
    ServiceTypes=KonqPopupMenu/Plugin
    X-KDE-ServiceTypes=KonqPopupMenu/Plugin
    MimeType=all/allfiles;inode/directory;${lib.concatStringsSep ";" archiveMimeTypes};
    Actions=CompressWithArk;CompressZipWithArk;ExtractHere;ExtractToSubfolder;
    X-KDE-Priority=TopLevel
    X-KDE-Submenu=Archive

    [Desktop Action CompressWithArk]
    Name=Compress...
    Icon=ark
    Exec=${arkBin} --add --changetofirstpath --dialog %F

    [Desktop Action CompressZipWithArk]
    Name=Compress to ZIP Here
    Icon=ark
    Exec=${arkBin} --batch --add --changetofirstpath --autofilename zip %F

    [Desktop Action ExtractHere]
    Name=Extract Here
    Icon=archive-extract
    Exec=${arkBin} --batch --destination %d %F

    [Desktop Action ExtractToSubfolder]
    Name=Extract to Subfolder
    Icon=archive-extract
    Exec=${arkBin} --batch --autodestination --autosubfolder %F
  '';
in
{
  home.packages = with pkgs; [
    # `sweet` was removed upstream over gtk-engine-murrine (#549887) and is
    # vendored again at pkgs/sweet.nix (murrine-free); the Sweet-Dark theme
    # files ship via the dataFile entry below and gtk-settings reference it.
    kdePackages.xdg-desktop-portal-kde
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
  ];

  home.sessionVariables = {
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QUICK_CONTROLS_STYLE = "org.kde.desktop";
    XDG_MENU_PREFIX = "plasma-";
    GTK_USE_PORTAL = "1";
  };

  xdg = {
    enable = true;

    mimeApps = {
      enable = true;
      defaultApplications = mimeDefaults;
      associations.added = mimeAssociations;
    };

    configFile = {
      "mimeapps.list".force = true;
      "menus/applications.menu" = {
        text = applicationsMenu;
        force = true;
      };
      "xdg-desktop-portal/niri-portals.conf" = {
        text = portalConfig;
        force = true;
      };
      "xdg-desktop-portal/portals.conf" = {
        text = portalConfig;
        force = true;
      };
      "gtk-3.0/settings.ini" = {
        text = gtkSettings;
        force = true;
      };
      "gtk-3.0/gtkfilechooser.ini" = {
        text = gtkFileChooserSettings;
        force = true;
      };
      "gtk-4.0/settings.ini" = {
        text = gtkSettings;
        force = true;
      };
      "konsolerc" = {
        text = konsoleRc;
        force = true;
      };

      "Kvantum/Dr460nized" = {
        source = "${garudaDr460nized}/usr/share/Kvantum/Dr460nized";
        force = true;
      };
      "Kvantum/kvantum.kvconfig" = {
        text = ''
          [General]
          theme=Dr460nized
        '';
        force = true;
      };
      "systemd/user/xdg-desktop-portal-gnome.service" = {
        source = "${pkgs.xdg-desktop-portal-gnome}/share/systemd/user/xdg-desktop-portal-gnome.service";
        force = true;
      };
      # The KDE portal's D-Bus activation file names this Plasma-prefixed
      # unit. Generic Linux Home Manager does not install upstream user units
      # globally, so expose the exact unit that FileChooser activation needs.
      "systemd/user/plasma-xdg-desktop-portal-kde.service" = {
        source = "${pkgs.kdePackages.xdg-desktop-portal-kde}/share/systemd/user/plasma-xdg-desktop-portal-kde.service";
        force = true;
      };
    };

    dataFile = {
      "applications/mimeapps.list" = {
        text = mimeAppsText;
        force = true;
      };
      "applications/org.kde.dolphin.desktop" = {
        text = dolphinDesktop;
        force = true;
      };
      "applications/org.kde.ark.desktop" = {
        text = arkDesktop;
        force = true;
      };
      "applications/com.obsproject.Studio.desktop" = {
        text = obsStudioDesktop;
        force = true;
      };
      "konsole/Garuda.profile" = {
        text = konsoleProfile;
        force = true;
      };
      "konsole/Sweet.colorscheme" = {
        text = konsoleSweetColorScheme;
        force = true;
      };
      "xdg-desktop-portal/portals/kde-niri.portal" = {
        text = kdeNiriPortal;
        force = true;
      };
      "applications/org.kde.okular.desktop" = {
        text = okularDesktop [ "application/vnd.kde.okular-archive" ];
        force = true;
      };
      "applications/okularApplication_pdf.desktop" = {
        text = okularDesktop [ "application/pdf" "application/x-gzpdf" "application/x-bzpdf" "application/x-wwf" ];
        force = true;
      };
      "applications/okularApplication_md.desktop" = {
        text = okularDesktop [ "text/markdown" ];
        force = true;
      };
      "applications/okularApplication_txt.desktop" = {
        text = okularDesktop [ "text/plain" ];
        force = true;
      };
      "applications/okularApplication_kimgio.desktop" = {
        text = okularDesktop [ "image/bmp" "image/gif" "image/jpeg" "image/png" "image/webp" "image/tiff" "image/avif" "image/heif" "image/jxl" ];
        force = true;
      };
      "applications/okularApplication_tiff.desktop" = {
        text = okularDesktop [ "image/tiff" ];
        force = true;
      };
      "applications/okularApplication_epub.desktop" = {
        text = okularDesktop [ "application/epub+zip" ];
        force = true;
      };
      "applications/okularApplication_comicbook.desktop" = {
        text = okularDesktop [ "application/vnd.comicbook+zip" "application/vnd.comicbook-rar" ];
        force = true;
      };

      "dbus-1/services/org.freedesktop.FileManager1.service" = {
        text = ''
          [D-BUS Service]
          Name=org.freedesktop.FileManager1
          Exec=env ${dolphinEnv} ${dolphinBin} --daemon
        '';
        force = true;
      };
      "kio/servicemenus/dolphin-dr460nized-actions.desktop" = {
        text = serviceMenu;
        force = true;
      };
      "kio/servicemenus/ark-compress-extract.desktop" = {
        text = arkServiceMenu;
        force = true;
      };

      "color-schemes/Sweet.colors" = {
        source = "${garudaDr460nized}/usr/share/plasma/desktoptheme/Dr460nized/colors";
        force = true;
      };
      "icons/BeautyLine" = {
        source = beautylineSrc;
        force = true;
      };
      "icons/candy-icons" = {
        source = candyIconsSrc;
        force = true;
      };
      # Vendored sweet (pkgs/sweet.nix): upstream dropped the theme over the
      # gtk-engine-murrine deprecation (nixpkgs #549887); the GTK3/GTK4 theme
      # builds and renders without that engine.
      "themes/Sweet-Dark" = {
        source = "${sweet}/share/themes/Sweet-Dark";
        force = true;
      };
      "plasma/desktoptheme/Dr460nized" = {
        source = "${garudaDr460nized}/usr/share/plasma/desktoptheme/Dr460nized";
        force = true;
      };
      "plasma/desktoptheme/Dr460nized-Candy" = {
        source = "${garudaDr460nized}/usr/share/plasma/desktoptheme/Dr460nized-Candy";
        force = true;
      };
      "plasma/look-and-feel/Dr460nized" = {
        source = "${garudaDr460nized}/usr/share/plasma/look-and-feel/Dr460nized";
        force = true;
      };
      "aurorae/themes/Sweet-Dark" = {
        source = "${garudaDr460nized}/usr/share/aurorae/themes/Sweet-Dark";
        force = true;
      };
      "wallpapers/Malefor" = {
        source = "${garudaDr460nized}/usr/share/wallpapers/Malefor";
        force = true;
      };
    };
  };


  home.file.".local/bin/niri-close-window" = {
    force = true;
    executable = true;
    text = ''
      #!/bin/sh
      set -eu

      window_id=
      if [ "''${1:-}" = "--id" ]; then
        window_id="''${2:-}"
      fi

      if [ -n "$window_id" ]; then
        window_info="$(niri msg windows 2>/dev/null | awk -v id="$window_id" '
          $0 == "Window ID " id ":" { print; capture=1; next }
          capture && /^Window ID / { exit }
          capture { print }
        ')"
      else
        window_info="$(niri msg focused-window 2>/dev/null || true)"
      fi

      if [ -z "$window_info" ]; then
        exec niri msg action close-window
      fi

      id="$(printf '%s\n' "$window_info" | sed -n 's/^Window ID \([0-9][0-9]*\):.*/\1/p' | head -n1)"
      app_id="$(printf '%s\n' "$window_info" | sed -n 's/^  App ID: "\(.*\)"/\1/p' | head -n1)"
      title="$(printf '%s\n' "$window_info" | sed -n 's/^  Title: "\(.*\)"/\1/p' | head -n1)"
      pid="$(printf '%s\n' "$window_info" | sed -n 's/^  PID: \([0-9][0-9]*\).*/\1/p' | head -n1)"

      is_trainer=0
      case "$app_id:$title" in
        gamescope:*[Tt][Rr][Aa][Ii][Nn][Ee][Rr]*|\
        gamescope:*[Cc][Hh][Ee][Aa][Tt]*|\
        gamescope:*[Ff][Ll][Ii][Nn][Gg]*)
          is_trainer=1
          ;;
      esac

      if [ "$is_trainer" -ne 1 ]; then
        if [ -n "$id" ]; then
          exec niri msg action close-window --id "$id"
        fi
        exec niri msg action close-window
      fi

      # Wine trainer windows inside gamescope ignore Niri's normal close-window
      # request, so keep MOD+Q graceful for normal windows but make it a hard
      # close for the focused LaLa trainer container.
      if [ -n "$id" ]; then
        niri msg action close-window --id "$id" >/dev/null 2>&1 || true
      fi
      sleep 0.25
      if [ -n "$id" ] && ! niri msg windows 2>/dev/null | grep -q "^Window ID $id:"; then
        exit 0
      fi

      descendants() {
        parent="$1"
        pgrep -P "$parent" 2>/dev/null | while read -r child; do
          printf '%s\n' "$child"
          descendants "$child"
        done
      }

      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        children="$(descendants "$pid" | awk '!seen[$0]++' || true)"
        targets="$(printf '%s\n%s\n' "$children" "$pid" | awk 'NF && !seen[$0]++')"
        if [ -n "$targets" ]; then
          printf '%s\n' "$targets" | xargs -r kill -TERM 2>/dev/null || true
          sleep 0.75
          still_alive="$(printf '%s\n' "$targets" | while read -r target; do
            if [ -n "$target" ] && kill -0 "$target" 2>/dev/null; then
              printf '%s\n' "$target"
            fi
          done)"
          if [ -n "$still_alive" ]; then
            printf '%s\n' "$still_alive" | xargs -r kill -KILL 2>/dev/null || true
          fi
        fi
      fi
    '';
  };

  home.file.".local/bin/obs" = {
    force = true;
    executable = true;
    text = ''
      #!/bin/sh
      set -eu

      self="$(readlink -f "$0" 2>/dev/null || printf '%s\n' "$0")"
      obs_bin=

      old_ifs=$IFS
      IFS=:
      for dir in $PATH; do
        candidate="$dir/obs"
        candidate_real="$(readlink -f "$candidate" 2>/dev/null || printf '%s\n' "$candidate")"
        if [ -x "$candidate" ] && [ "$candidate_real" != "$self" ]; then
          obs_bin=$candidate
          break
        fi
      done
      IFS=$old_ifs

      if [ -z "$obs_bin" ]; then
        echo "obs wrapper: could not find the real OBS executable" >&2
        exit 127
      fi

      # Niri/Wayland window capture works through OBS' PipeWire portal source.
      # Keep OBS_QPA_PLATFORM=xcb as an explicit fallback for Qt/Wayland regressions,
      # but default to Wayland so OBS does not steer users toward Xcomposite capture.
      exec env QT_QPA_PLATFORM="''${OBS_QPA_PLATFORM:-wayland}" "$obs_bin" "$@"
    '';
  };

  home.activation.configureDolphinSweet = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export QT_STYLE_OVERRIDE=kvantum
    export QT_QUICK_CONTROLS_STYLE=org.kde.desktop
    export XDG_MENU_PREFIX=plasma-
    # GTK_THEME removed (Phase 0 Option C): the system picks a default
    # theme from the desktop environment at activation. Add a
    # `export GTK_THEME=<theme>` line here if a specific look is needed.
    export GTK_USE_PORTAL=1

    kwrite=${pkgs.kdePackages.kconfig}/bin/kwriteconfig6

    # ColorScheme removed (Phase 0 Option C): KDE inherits from the
    # desktop environment default. Pick a specific scheme by re-adding
    # the original line if desired.
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group General --key fixed 'FiraCode Nerd Font Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group General --key font 'Fira Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group General --key menuFont 'Fira Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group General --key smallestReadableFont 'Fira Sans,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group General --key toolBarFont 'Fira Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group KDE --key LookAndFeelPackage Dr460nized
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group KDE --key SingleClick true
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group KDE --key widgetStyle kvantum
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group KDE --key contrast 4
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group Icons --key Theme BeautyLine
    $DRY_RUN_CMD "$kwrite" --file kdeglobals --group WM --key activeFont 'Fira Sans,10,-1,5,75,0,0,0,0,0,Bold'

    # okularrc ColorScheme removed (Phase 0 Option C); pick a specific
    # scheme by re-adding the original line if desired.
    $DRY_RUN_CMD "$kwrite" --file okularrc --group UiSettings --key ColorScheme BreezeClassic || true
    $DRY_RUN_CMD "$kwrite" --file okularrc --group General --key ShowSidebar true
    $DRY_RUN_CMD "$kwrite" --file okularrc --group General --key LockSidebar true

    # Keep Dolphin's view state user-owned.  Dolphin stores view mode, hidden
    # files, previews, sorting, and per-folder/global view properties in
    # dolphinrc and ~/.local/share/dolphin/view_properties.  Do not rewrite
    # those here; otherwise Home Manager activations reset interactive Dolphin
    # choices between sessions.
    $DRY_RUN_CMD mkdir -p "$HOME/.config/qt5ct" "$HOME/.config/qt6ct"

    # qt5ct stores some settings as Qt-serialized @Variant/@ByteArray values.
    # Stale values may contain short \x escapes that KConfig warns about every
    # time kwriteconfig6 rewrites this file. They are UI-local/volatile, so
    # drop them before writing the declarative settings below.
    if [ -f "$HOME/.config/qt5ct/qt5ct.conf" ]; then
      $DRY_RUN_CMD ${pkgs.perl}/bin/perl -0pi -e 's/^\[Fonts\]\n(?:.*\n)*?(?=^\[|\z)//mg; s/^\[SettingsWindow\]\n(?:.*\n)*?(?=^\[|\z)//mg' "$HOME/.config/qt5ct/qt5ct.conf"
    fi

    $DRY_RUN_CMD "$kwrite" --file qt5ct/qt5ct.conf --group Appearance --key style kvantum
    $DRY_RUN_CMD "$kwrite" --file qt5ct/qt5ct.conf --group Appearance --key icon_theme BeautyLine
    $DRY_RUN_CMD "$kwrite" --file qt5ct/qt5ct.conf --group Interface --key activate_item_on_single_click 1
    $DRY_RUN_CMD "$kwrite" --file qt5ct/qt5ct.conf --group Interface --key dialog_buttons_have_icons 1
    $DRY_RUN_CMD "$kwrite" --file qt5ct/qt5ct.conf --group Interface --key menus_have_icons true
    $DRY_RUN_CMD "$kwrite" --file qt6ct/qt6ct.conf --group Appearance --key style kvantum
    $DRY_RUN_CMD "$kwrite" --file qt6ct/qt6ct.conf --group Appearance --key icon_theme BeautyLine
    $DRY_RUN_CMD "$kwrite" --file qt6ct/qt6ct.conf --group Interface --key activate_item_on_single_click 1
    $DRY_RUN_CMD "$kwrite" --file qt6ct/qt6ct.conf --group Interface --key dialog_buttons_have_icons 1
    $DRY_RUN_CMD "$kwrite" --file qt6ct/qt6ct.conf --group Interface --key menus_have_icons true

    # Sweet-Dark restored (vendored pkgs/sweet.nix): matches the
    # gtk-theme-name already declared in gtk-3.0/gtk-4.0 settings.ini.
    $DRY_RUN_CMD ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme Sweet-Dark 2>/dev/null || true
    $DRY_RUN_CMD ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface icon-theme BeautyLine 2>/dev/null || true
    $DRY_RUN_CMD ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    $DRY_RUN_CMD ${pkgs.python3}/bin/python3 - <<'PY'
    from pathlib import Path

    prefs = {
        'widget.use-xdg-desktop-portal.file-picker': 1,
        'widget.use-xdg-desktop-portal.mime-handler': 1,
        'widget.use-xdg-desktop-portal.open-uri': 1,
    }

    home = Path.home()
    profiles = []
    for root in [home / ".zen", home / ".mozilla" / "firefox"]:
        if root.exists():
            profiles.extend({p.parent for p in root.glob("*/prefs.js")})

    for profile in profiles:
        user_js = profile / "user.js"
        existing = user_js.read_text() if user_js.exists() else ""
        lines = [
            line for line in existing.splitlines()
            if not any(f'"{key}"' in line for key in prefs)
        ]
        if lines and lines[-1].strip():
            lines.append("")
        lines.append("// Managed by Home Manager: use themed xdg-desktop-portal file dialogs.")
        for key, value in prefs.items():
            lines.append(f'user_pref("{key}", {value});')
        user_js.write_text("\n".join(lines) + "\n")
    PY
    if [ -f "$HOME/.local/share/xdg-desktop-portal/portals/kde.portal" ] && [ ! -L "$HOME/.local/share/xdg-desktop-portal/portals/kde.portal" ]; then
      $DRY_RUN_CMD rm "$HOME/.local/share/xdg-desktop-portal/portals/kde.portal"
    fi
    $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user import-environment QT_STYLE_OVERRIDE QT_QUICK_CONTROLS_STYLE XDG_MENU_PREFIX GTK_THEME GTK_USE_PORTAL 2>/dev/null || true
    $DRY_RUN_CMD ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd QT_STYLE_OVERRIDE QT_QUICK_CONTROLS_STYLE XDG_MENU_PREFIX GTK_THEME GTK_USE_PORTAL 2>/dev/null || true
    $DRY_RUN_CMD ${pkgs.desktop-file-utils}/bin/update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
    $DRY_RUN_CMD env XDG_MENU_PREFIX=plasma- ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user daemon-reload 2>/dev/null || true
    $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-gnome.service xdg-desktop-portal-kde.service xdg-desktop-portal-gtk.service 2>/dev/null || true
  '';
}
