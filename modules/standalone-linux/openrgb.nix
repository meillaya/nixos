# OpenRGB as a system package, with the udev rules it generates at build time.
#
# openrgb.org/udev documents that OpenRGB 1.0 and later generate the rules from
# the binary, so this module uses the copy that nixpkgs' package writes to
# $out/lib/udev/rules.d/60-openrgb.rules. The rules use TAG+="uaccess", which
# grants the active session access without adding the user to a device group.
{ config, lib, pkgs, ... }:

let
  cfg = config.standalone.openrgb;
in
{
  options.standalone.openrgb.enable = lib.mkEnableOption "OpenRGB and its udev integration";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.openrgb ];

    environment.etc."udev/rules.d/60-openrgb.rules".source =
      "${pkgs.openrgb}/lib/udev/rules.d/60-openrgb.rules";

    environment.etc."modules-load.d/i2c-dev.conf".text = "i2c-dev\n";

    systemd.services.openrgb-udev-reload = {
      description = "Reload udev rules for OpenRGB and load i2c-dev";
      wantedBy = [ "system-manager.target" ];
      before = [ "system-manager.target" ];
      after = [ "systemd-udevd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "openrgb-udev-reload" ''
          ${pkgs.kmod}/bin/modprobe i2c-dev || true
          ${pkgs.systemd}/bin/udevadm control --reload-rules
          ${pkgs.systemd}/bin/udevadm trigger
        '';
      };
    };
  };
}
