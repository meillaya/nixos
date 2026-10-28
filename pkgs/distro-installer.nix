# Wrapper for the live ISO's offline installer.
#
# The Python script owns disk selection and partitioning; this wrapper pins
# the prebuilt system, the flake source, and the label names so the script
# cannot drift from modules/nixos/storage-labels.nix.
{ lib
, writeShellApplication
, python3
, util-linux
, btrfs-progs
, dosfstools
, coreutils
, gnugrep
, gawk
, installedSystem
, flakeSource
, labels
, liveUser
}:

writeShellApplication {
  name = "nixos-install-tui";
  runtimeInputs = [
    python3
    util-linux
    btrfs-progs
    dosfstools
    coreutils
    gnugrep
    gawk
  ];
  text = ''
    export NIXOS_INSTALLED_SYSTEM=${lib.escapeShellArg installedSystem}
    export NIXOS_FLAKE_SOURCE=${lib.escapeShellArg flakeSource}
    export NIXBOOT_LABEL=${lib.escapeShellArg labels.boot}
    export NIXROOT_LABEL=${lib.escapeShellArg labels.root}
    export NIXOS_LIVE_USER=${lib.escapeShellArg liveUser}
    exec python3 ${../scripts/distro/install.py} "$@"
  '';
}
