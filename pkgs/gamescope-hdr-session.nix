# A gamescope session for the HDR monitor.
#
# Niri has no HDR output or color management, so the normal desktop and every
# Niri application stay SDR. This session hands the monitor to gamescope
# instead: gamescope becomes the DRM compositor, sets HDR metadata on the
# output, and exposes HDR to its clients through the gamescope WSI layer.
#
# It launches the host packages on purpose. CachyOS owns Steam, gamescope,
# Mesa, and the Vulkan stack for games, and those are the copies the games
# already run against. The Nix wrappers would put a second driver tree in
# front of them.
#
# SDDM lists the session from `share/wayland-sessions`; the module writes the
# matching `SessionDir` override. Edit the connector below if the HDR monitor
# moves to a different output.

{ lib, symlinkJoin, writeShellApplication, writeTextDir }:

let
  session = writeShellApplication {
    name = "gamescope-hdr-session";
    text = ''
      # SDDM starts a Wayland session. Gamescope needs the DRM backend, and
      # Steam is an X11 client, so drop the inherited display variables and the
      # Nix library path before taking over the output.
      unset DISPLAY XAUTHORITY WAYLAND_DISPLAY LD_LIBRARY_PATH LD_PRELOAD
      export XDG_SESSION_TYPE=x11
      export XDG_CURRENT_DESKTOP=gamescope
      export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

      # The WSI layer is how DXVK and vkd3d-proton see HDR support from the
      # game's Vulkan device. DXVK_HDR keeps SDR games tonemapped SDR unless
      # they opt into HDR.
      export ENABLE_GAMESCOPE_WSI=1
      export DXVK_HDR=1
      export STEAM_GAMESCOPE_HDR_SUPPORTED=1
      export STEAM_GAMESCOPE_FORCE_HDR_DEFAULT=1
      export STEAM_GAMESCOPE_FORCE_OUTPUT_TO_HDR10PQ_DEFAULT=1
      export STEAM_GAMESCOPE_COLOR_MANAGED=1
      export STEAM_GAMESCOPE_VRR_SUPPORTED=1

      # The Dell S3422DWG is the DisplayPort output on this host. Gamescope
      # rejects an output list that matches nothing, so change this if the
      # monitor is docked elsewhere.
      exec dbus-run-session -- /usr/bin/gamescope \
        --backend drm \
        --hdr-enabled \
        --hdr-itm-enabled \
        -f -e \
        -O DP-1 \
        -- /usr/bin/steam -steamos3 -steampal -steamdeck -gamepadui
    '';
  };

  desktop = writeTextDir "share/wayland-sessions/gamescope-hdr.desktop" ''
    [Desktop Entry]
    Encoding=UTF-8
    Name=Gamescope HDR
    Comment=Steam Big Picture with HDR output
    Exec=${session}/bin/gamescope-hdr-session
    Icon=steam
    Type=Application
    DesktopNames=gamescope
  '';
in
symlinkJoin {
  name = "gamescope-hdr-session";
  paths = [
    session
    desktop
  ];
  meta.description = "Gamescope session with HDR output for the Dell S3422DWG";
}
