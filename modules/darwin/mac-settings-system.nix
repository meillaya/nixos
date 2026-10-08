# The machine's own macOS settings, the ones that need root, in the option
# tree of nix-plist-manager. Read back with
#   nix run github:sushydev/nix-plist-manager#current -- mac.nix --scope system
#
# Three captured entries are deliberately absent:
#
#   - general.dateAndTime.timeZone. modules/aspects/named-hosts/entropy.nix
#     already forces time.timeZone from the machine record, and a second
#     writer for the same fact is how the two drift apart.
#   - general.sharing.fileSharingOptions.sharedFolders. Its only key is this
#     account's home directory and its value the account's display name, so
#     committing it would hardcode both. File sharing is off anyway.
#   - general.dateAndTime.source, along with
#     general.dateAndTime.setTimeAndDateAutomatically, which the capture never
#     reported. The server reads time.apple.com, which is what Apple ships, and
#     it means nothing next to a switch that lives in /var/db/timed and cannot
#     be read back without root. Declaring either half alone makes
#     nix-plist-manager warn about the pair.
#
# The nix-darwin payload of den.aspects.nix-plist-manager imports this file.
{
  applications = {
    systemSettings = {
      battery = {
        options = {
          preventAutomaticSleepingOnPowerAdapterWhenTheDisplayIsOff = false;
        };
      };
      general = {
        dateAndTime = {
          # The zone follows the location, so the named host owns the zone
          # itself. See the header for the server and the automatic switch.
          setTimeZoneAutomaticallyUsingYourCurrentLocation = true;
        };
        sharing = {
          contentCaching = false;
          fileSharing = false;
          printerSharing = false;
          remoteApplicationScripting = false;
          remoteApplicationScriptingOptions = {
            allowAccessFor = "Only these users";
          };
          remoteManagement = false;
          screenSharing = false;
          screenSharingOptions = {
            allowAccessFor = "Only these users";
          };
        };
        softwareUpdate = {
          automaticallyDownloadNewUpdatesWhenAvailable = true;
          automaticallyInstallApplicationUpdatesFromTheAppStore = false;
          automaticallyInstallMacOSUpdates = true;
          automaticallyInstallSystemDataFilesAndSecurityUpdates = true;
        };
      };
      lockScreen = {
        turnDisplayOffOnPowerAdapterWhenInactive = "For 2 hours";
      };
      network = {
        # The firewall is off on this machine, which is how it was found. The
        # options block stops short of blockAllIncomingConnections, because
        # declaring it emits `socketfilterfw --setblockall`, and on macOS 27
        # that call turns the firewall back on after `--setglobalstate off` has
        # already run. The ALF log shows it as "AFSetBlockAll() setting block
        # state to: 2" followed by "turning firewall on", so the two entries
        # cannot both hold. Left unmanaged, block all stays at its own default
        # and still reads as off.
        firewall = {
          firewall = false;
          options = {
            automaticallyAllowBuiltInSoftwareToReceiveIncomingConnections = true;
            automaticallyAllowDownloadedSignedSoftwareToReceiveIncomingConnections = true;
            enableStealthMode = false;
          };
        };
      };
      privacyAndSecurity = {
        analyticsAndImprovements = {
          shareMacAnalytics = false;
          shareWithAppDevelopers = false;
        };
      };
    };
  };
}
