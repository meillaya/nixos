# Graphical wrapper for the offline installer.
#
# The wrapper collects the target disk and the login password with Zenity, then
# runs nixos-install-tui. Disk eligibility, partitioning, the installed closure,
# and the password write stay in distro/scripts/install.py.
{
  lib,
  writeShellApplication,
  symlinkJoin,
  makeDesktopItem,
  zenity,
  jq,
  coreutils,
  installer,
  liveUser,
  distroName,
}:
let
  app = writeShellApplication {
    name = "nixos-install-gui";
    runtimeInputs = [
      zenity
      jq
      coreutils
    ];
    text = ''
      export NIXOS_INSTALLER=${lib.escapeShellArg "${installer}/bin/nixos-install-tui"}
      export NIXOS_LIVE_USER=${lib.escapeShellArg liveUser}
      export NIXOS_DISTRO_NAME=${lib.escapeShellArg distroName}
      ${builtins.readFile ../scripts/install-gui.sh}
    '';
  };

  desktop = makeDesktopItem {
    name = "nixos-install-gui";
    desktopName = "${distroName} Installer";
    genericName = "System installer";
    comment = "Install the prebuilt ${distroName} system on this machine";
    exec = "nixos-install-gui";
    icon = "drive-harddisk";
    terminal = false;
    categories = [ "System" ];
  };
in
symlinkJoin {
  name = "nixos-install-gui";
  paths = [
    app
    desktop
  ];
}
