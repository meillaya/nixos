let
  validators = import ./validators.nix;

  machines = {
    remembrance = {
      hostId = "remembrance";
      target = "nixosConfigurations.remembrance";
      system = "x86_64-linux";
      role = "workstation";
      identity = {
        name = "mei";
        home = "/home/mei";
        uid = 1000;
        gid = 100;
      };
      location = {
        timeZone = "America/New_York";
        locale = "en_US.UTF-8";
        keymap = "us";
        xkb = "us";
      };
      display.scale = {
        numerator = 1;
        denominator = 1;
      };
      boot.state = "disabled";
      storage.profile = "none";
      publicTrust.state = "disabled";
      secretTrust.state = "disabled";
      cpuVendor = "pending";
      firmware = "disabled";
      kernel = "disabled";
      gpu = "disabled";
      network = "disabled";
      devices.state = "disabled";
      capabilities.state = "disabled";
      ddcConnectors = [ ];
      remoteInstall = false;
      platformExpectations.kind = "none";
    };

    antagony = {
      hostId = "antagony";
      target = "nixosConfigurations.antagony";
      system = "x86_64-linux";
      role = "workstation";
      identity = {
        name = "mei";
        home = "/home/mei";
        uid = 1000;
        gid = 100;
      };
      location = {
        timeZone = "America/New_York";
        locale = "en_US.UTF-8";
        keymap = "us";
        xkb = "us";
      };
      display.scale = {
        numerator = 1;
        denominator = 1;
      };
      boot.state = "disabled";
      storage.profile = "none";
      publicTrust.state = "disabled";
      secretTrust.state = "disabled";
      cpuVendor = "pending";
      firmware = "disabled";
      kernel = "disabled";
      gpu = "disabled";
      network = "disabled";
      devices.state = "disabled";
      capabilities.state = "disabled";
      ddcConnectors = [ ];
      remoteInstall = false;
      platformExpectations.kind = "none";
    };

    entropy = {
      hostId = "entropy";
      target = "darwinConfigurations.entropy";
      system = "aarch64-darwin";
      role = "workstation";
      identity = {
        name = "mei";
        home = "/Users/mei";
        uid = 501;
        gid = 20;
      };
      location = {
        timeZone = "America/New_York";
        locale = "en_US.UTF-8";
        keymap = "us";
        xkb = "us";
      };
      display.scale = {
        numerator = 2;
        denominator = 1;
      };
      boot.state = "disabled";
      storage.profile = "none";
      publicTrust.state = "disabled";
      secretTrust.state = "disabled";
      cpuVendor = "Apple";
      firmware = "apple";
      kernel = "disabled";
      gpu = "apple-metal";
      network = "native-darwin";
      devices.state = "disabled";
      capabilities.state = "disabled";
      ddcConnectors = [ ];
      remoteInstall = false;
      platformExpectations = {
        kind = "darwin";
        networkServiceClass = "wifi";
        requiredTccServices = [
          "accessibility"
          "screen"
        ];
        managedApps = [
          {
            bundleId = "net.kovidgoyal.kitty";
            appPathDigest = "1c39a5172a1d2e066d229e4b8470b1ae16b7876d9739679eea7892483665af68";
          }
          {
            bundleId = "org.gnu.Emacs";
            appPathDigest = "30220b125631ef7ead4cf80163652de5434cb77a37b20ac95ce851968dde77c7";
          }
        ];
        kitty = {
          fontFamily = "FiraCode Nerd Font Mono";
          fontDigest = "a44558037e371dd6b1f2c249ad41d57f2a501e921a908d2901e2d50e7d91bebc";
          configDigest = "1fc305cb003d77d9fd8dbfd07195bbd0a741a539f4313a7f602c5b2f4a026daa";
          colorDigest = "3d3e13bd53d8d929ab9810a4c94ec7c068804a7914617cc9979a963e5cc0f323";
        };
        wallpaperPathDigest = "b227770eeb1224fec017992bf7cd348b0b412145c35d86a9bcaa5fa597253aeb";
        emacs = {
          pathDigest = "316577c1989a42a43a900a42de262c394cc4f3b7e76626e68b448a532c265bc7";
          initDigest = "b39003e167b2d6b3ca9066834a0f9ee1064e2adff6be65410c9a622739a6c545";
          packageSetDigest = "6662492dd57de092f1be5a1672cec45aa8be07564b6d61c5abe0527a94c260e1";
        };
      };
    };  };

  machineIds = builtins.attrNames machines;
  getMachine =
    hostId:
    if builtins.hasAttr hostId machines then
      validators.assertValid (builtins.getAttr hostId machines)
    else
      throw "unknown declared machine: ${hostId}";
  allowsSystemMutation = machine:
    let validated = validators.assertValid machine;
    in
    validated.boot.state != "disabled"
    || validated.storage.profile != "none"
    || validated.capabilities.state == "enrolled";
in
validators
// {
  inherit machines machineIds getMachine allowsSystemMutation;
  declaredMachineIds = machineIds;
  isDeclaredMachineId = hostId: builtins.hasAttr hostId machines;
}
