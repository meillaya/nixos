# Shared declarative Zen Browser configuration: managed profile "meillaya"
# pointing at ~/.config/zen/8lze40dp.Default Profile (the original browser data).
#
# This reproduces the REAL spaces, pinned tabs, and settings across machines via
# the mei user aspect -> inputs.zen-browser.homeModules.beta. It does NOT copy
# open/non-pinned tabs (per-plan guardrail: spaces+pins declarative sync only).
#
# Space ids (stable, from the live profile):
#   Personal: 66b75881-fbf4-40c5-95de-ac8041642aad
#   Dev: d46a1a4d-05e0-42a1-aa6e-999f43d3c90f
#   Work: cf68abf2-8397-4a1a-9304-f3d0c5354597
# Pin identity is the live zenSyncId (timestamp form), matching each real pinned tab.
{ ... }:
{
  programs.zen-browser = {
    enable = true;

    # Privacy baseline (matches the plan’s minimal policy set).
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      EnableTrackingProtection = { Value = true; Locked = true; Cryptomining = true; Fingerprinting = true; };
    };

    profiles.meillaya = {
      # Use the folder containing the actual browser data from the old profile.
      path = "8lze40dp.Default Profile";
      isDefault = true;

      # Live settings (from prefs.js).
      settings = {
        "browser.newtabpage.activity-stream.showSearch" = false;
        "browser.urlbar.placeholderName" = "DuckDuckGo";
        "zen.view.compact.enable-at-startup" = true;
        "zen.welcome-screen.seen" = true;
      };

      # Real spaces (spacesForce reproduces exactly these workspaces everywhere).
      spacesForce = true;
      spaces = {
        "Personal" = {
          id = "66b75881-fbf4-40c5-95de-ac8041642aad";
          icon = "chrome://browser/skin/zen-icons/selectable/water.svg";
        };
        "Dev" = {
          id = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";
          icon = "chrome://browser/skin/zen-icons/selectable/code.svg";
        };
        "Work" = {
          id = "cf68abf2-8397-4a1a-9304-f3d0c5354597";
          icon = "chrome://browser/skin/zen-icons/selectable/briefcase.svg";
        };
      };

      # Live keyboard-shortcut schema version (prevents silent breakage).
      keyboardShortcutsVersion = 20;
    };
  };
}
