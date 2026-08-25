{ den, ... }:
let
  routing =
    { host, ... }:
    let
      machine = host.machine;
      enrolled = machine.cpuVendor != "pending";
      intel = machine.cpuVendor == "GenuineIntel";
      amd = machine.cpuVendor == "AuthenticAMD";
    in
    {
      nixos =
        { lib, ... }:
        {
          hardware.cpu.intel.updateMicrocode = lib.mkIf intel true;
          hardware.cpu.amd.updateMicrocode = lib.mkIf amd true;
          hardware.enableRedistributableFirmware = lib.mkIf enrolled true;
          networking.networkmanager.enable = lib.mkIf (machine.network == "networkmanager") true;
          assertions = [
            {
              assertion = !intel || !amd;
              message = "a host cannot select both Intel and AMD microcode closures";
            }
            {
              assertion =
                !machine.remoteInstall
                || machine.capabilities.values."install.remote".state == "present";
              message = "remote install is bound to the enrolled capability projection";
            }
          ];
        };
    };
in
{
  den.aspects.remembrance-hardware-routing = routing;
  den.aspects.antagony-hardware-routing = routing;
}
