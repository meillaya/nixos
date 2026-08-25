{ den, ... }:
let
  capabilityPresent =
    machine: name:
    machine.capabilities.state == "enrolled"
    && machine.capabilities.values.${name}.state == "present";

  linuxRouting =
    { host, ... }:
    let
      machine = host.machine;
      audio = capabilityPresent machine "audio";
      bluetooth = capabilityPresent machine "bluetooth";
      ddc = capabilityPresent machine "ddc";
      gpu = capabilityPresent machine "gpu";
      power = capabilityPresent machine "power";
      powerDaemon = machine.devices.powerDaemon or null;
      suspend = capabilityPresent machine "suspend";
    in
    {
      nixos =
        { lib, ... }:
        {
          # Enrolled capabilities add their required services. Disabled and
          # evaluation records deliberately do not force options off: current
          # upstream feature modules, including Noctalia's recommended service
          # set, retain ownership of their own runtime prerequisites.
          hardware.bluetooth.enable = lib.mkIf bluetooth true;
          services.pipewire.enable = lib.mkIf audio true;
          services.pipewire.alsa.enable = lib.mkIf audio true;
          services.pipewire.alsa.support32Bit = lib.mkIf audio true;
          services.pipewire.pulse.enable = lib.mkIf audio true;
          services.pipewire.wireplumber.enable = lib.mkIf audio true;
          security.rtkit.enable = lib.mkIf audio true;
          services.power-profiles-daemon.enable = lib.mkIf power true;
          services.upower.enable = lib.mkIf power true;
          services.logind.settings.Login.HandleLidSwitch = lib.mkIf suspend "suspend";
          services.logind.settings.Login.HandleLidSwitchDocked = lib.mkIf suspend "suspend";
          hardware.i2c.enable = lib.mkIf ddc true;
          users.groups.i2c.members = lib.mkIf ddc [ machine.identity.name ];
          services.udev.extraRules = lib.mkIf ddc ''
            KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660", TAG+="uaccess"
          '';

          assertions = [
            {
              assertion = !gpu || machine.gpu == "generic-vulkan";
              message = "GPU services require the generic-vulkan enrolled policy";
            }
            {
              assertion = power == (powerDaemon == "power-profiles-daemon");
              message = "power daemon selection must match the enrolled power capability";
            }
            {
              assertion = ddc == (machine.ddcConnectors != [ ]);
              message = "DDC service projection must match declared connectors";
            }
            {
              assertion = !suspend || machine.role == "workstation";
              message = "suspend capability is only applicable to workstation hosts";
            }
          ];
        };
    };

  darwinRouting =
    { host, ... }:
    let
      machine = host.machine;
    in
    {
      darwin.assertions = [
        {
          assertion = machine.capabilities.state == "disabled";
          message = "Darwin device enrollment remains disabled";
        }
        {
          assertion = machine.gpu == "apple-metal";
          message = "Darwin GPU policy must remain Apple Metal";
        }
      ];
    };
in
{
  den.aspects.remembrance-device-capability-routing = linuxRouting;
  den.aspects.antagony-device-capability-routing = linuxRouting;
  den.aspects.entropy-device-capability-routing = darwinRouting;
}
