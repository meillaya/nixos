# Shared declarative Zen Browser configuration.
#
# One fragment drives identical spaces, pinned tabs, settings, policies, and
# shortcuts on every host whose home is the `mei` user (NixOS, macOS, and
# standalone Linux), wired there through the mei user aspect's homeManager.
# Cross-machine parity comes from declaring the SAME
# stable space/pin UUIDs here — never from copying a browser profile folder
# (profiles are machine-InstallID-bound and fragile to copy).
#
# The UUIDs below are placeholders: edit them if you want to adopt an existing
# Zen profile's real space/pin ids. Keep each id stable once set — changing a
# space/pin id re-creates it (and with spacesForce/pinsForce the old entry is
# deleted).
#
# Canonical ids (generated once, reused across spaces/pins):
#   Personal space : df914405-a213-458f-ace7-164dd9c9087f
#   Work    space : 4105f787-3509-4cde-ab73-cee43dc30410
#   Email   pin   : b5a563f3-bea4-4239-9813-f7f269f36641
#   GitHub  pin   : ed1ec24f-f999-4845-a239-34caa788b179
#   News    pin   : 88dcd04b-498b-42eb-a9ce-1e2c31d01056
#   DevDocs pin   : 85a8262e-ba3c-46c7-af1c-e35c6519be9b
{ ... }:
{
  programs.zen-browser = {
    enable = true;

    # Enforced machine policy (policies.json). Privacy-minimal baseline.
    policies = {
      DisableAppUpdate = true;
      DisableFeedbackCommands = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      # NoDefaultBookmarks is intentionally absent: home-manager's firefox
      # module derives it from the declared profiles.*.bookmarks below.
      OfferToSaveLogins = false;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      # Purge private data on shutdown while keeping history/bookmarks/pins.
      SanitizeOnShutdown = {
        Cache = true;
        Cookies = true;
        Sessions = true;
        OfflineApps = true;
        SiteSettings = false;
      };
    };

    profiles.default = {
      # User prefs (prefs.js) — Zen + browser defaults.
      settings = {
        "browser.startup.homepage" = "about:home";
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.shell.checkDefaultBrowser" = false;
        "zen.urlbar.behavior" = "float";
        "zen.view.compact.hide-tabbar" = true;
        "zen.welcome-screen.seen" = true;
      };

      # Declared spaces. spacesForce deletes anything not declared here, so a
      # rebuild from any host yields exactly these workspaces.
      spacesForce = true;
      spaces = {
        "Personal" = {
          id = "df914405-a213-458f-ace7-164dd9c9087f";
          position = 1000;
          icon = "🏠";
        };
        "Work" = {
          id = "4105f787-3509-4cde-ab73-cee43dc30410";
          position = 2000;
          icon = "💼";
        };
      };

      # Pinned tabs. pinsForceAction = "demote" demotes an undeclared pinned
      # tab to a normal tab instead of removing it, so pins are idempotent
      # and lossless across hosts.
      pinsForce = true;
      pinsForceAction = "demote";
      pins = {
        "Email" = {
          id = "b5a563f3-bea4-4239-9813-f7f269f36641";
          url = "https://mail.protonmail.com";
          position = 100;
          isEssential = true;
        };
        "GitHub" = {
          id = "ed1ec24f-f999-4845-a239-34caa788b179";
          url = "https://github.com";
          position = 200;
          workspace = "df914405-a213-458f-ace7-164dd9c9087f"; # Personal
        };
        "News" = {
          id = "88dcd04b-498b-42eb-a9ce-1e2c31d01056";
          url = "https://news.ycombinator.com";
          position = 300;
          workspace = "df914405-a213-458f-ace7-164dd9c9087f"; # Personal
        };
        "DevDocs" = {
          id = "85a8262e-ba3c-46c7-af1c-e35c6519be9b";
          url = "https://devdocs.io";
          position = 400;
          workspace = "4105f787-3509-4cde-ab73-cee43dc30410"; # Work
        };
      };

      # Keyboard shortcut overrides. Version protection surfaces breaking
      # schema changes after Zen updates instead of silently failing.
      keyboardShortcuts = [
        {
          id = "zen-compact-mode-toggle";
          key = "c";
          modifiers.control = true;
        }
        {
          id = "zen-toggle-sidebar";
          key = "x";
          modifiers.control = true;
        }
      ];
      keyboardShortcutsVersion = 17;

      # Search engines with usable shortcuts.
      search = {
        force = true;
        default = "ddg";
        engines = {
          mynixos = {
            name = "My NixOS";
            urls = [
              {
                template = "https://mynixos.com/search?q={searchTerms}";
              }
            ];
            definedAliases = [ "@nx" ];
          };
        };
      };

      # Bookmarks (toolbar materializes on every rebuild).
      bookmarks = {
        force = true;
        settings = [
          {
            name = "Toolbar";
            toolbar = true;
            bookmarks = [
              {
                name = "NixOS Packages";
                url = "https://search.nixos.org/packages";
              }
              {
                name = "Zen Docs";
                url = "https://docs.zen-browser.app";
              }
            ];
          }
        ];
      };
    };
  };
}