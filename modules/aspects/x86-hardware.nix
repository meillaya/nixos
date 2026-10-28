# Hardware capabilities that used to be gated by a per-machine enrollment.
#
# Every x86 host now gets the same generic support: firmware, both microcode
# vendors, networking, audio, Bluetooth, power, i2c/DDC, and suspend. The
# machine no longer has to prove which devices it carries before they work.
{ den, ... }:
{
  den.aspects.x86-hardware = {
    nixos =
      { host, lib, ... }:
      let
        username = host.users.mei.identity.name;
      in
      {
        hardware = {
          enableRedistributableFirmware = true;
          cpu.intel.updateMicrocode = true;
          cpu.amd.updateMicrocode = true;
          bluetooth.enable = true;
          i2c.enable = true;
        };

        networking.networkmanager.enable = true;

        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          wireplumber.enable = true;
        };
        security.rtkit.enable = true;

        services.power-profiles-daemon.enable = true;
        services.upower.enable = true;

        users.groups.i2c.members = [ username ];
        services.udev.extraRules = ''
          KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660", TAG+="uaccess"
        '';

        services.logind.settings.Login = {
          HandleLidSwitch = "suspend";
          HandleLidSwitchDocked = "suspend";
        };

        zramSwap.enable = true;
      };
  };
}
