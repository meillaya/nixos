# This user's macOS preferences, in the option tree of nix-plist-manager.
#
# Read back from the machine with
#   nix run github:sushydev/nix-plist-manager#current -- mac.nix --scope user
# then curated. Five kinds of entry are dropped, because declaring them would
# pin whatever Apple ships today instead of recording a choice:
#
#   - values macOS reports as the literal "Default" (hover text, Live Captions,
#     text size), which name no actual preference
#   - empty attrsets (the per-app language list, the empty menu-item shortcut map)
#   - the all-true Spotlight result list, which is the state of a Spotlight
#     nobody has restricted
#   - the all-false modifier blocks under every hot corner, which matter only
#     next to an action, and only the bottom right corner has one
#   - the Dock's magnification size, which reads 16 while magnification is off.
#     Declaring it would also switch magnification on, since nix-plist-manager
#     reads a size off "Off" as the slider being moved.
#
# Run the same command with --against modules/darwin/mac-settings-user.nix
# after changing a setting in System Settings to see what moved.
#
# The home-manager payload of den.aspects.nix-plist-manager imports this file.
{
  applications = {
    finder = {
      menuBar = {
        view = {
          showSidebar = true;
        };
      };
      settings = {
        advanced = {
          removeItemsFromTheTrashAfter30Days = true;
          # Written by nix-darwin as NSGlobalDomain AppleShowAllExtensions
          # until this file took over that key.
          showAllFilenameExtensions = true;
        };
        general = {
          showTheseItemsOnTheDesktop = {
            cdsDvdsAndiPods = true;
            externalDisks = true;
            hardDisks = false;
          };
        };
      };
    };
    systemSettings = {
      accessibility = {
        audio = {
          backgroundSoundsOptions = {
            timer = false;
          };
        };
        pointerControl = {
          doubleClickSpeed = 1.4;
          trackpadOptions = {
            useTrackpadForScrolling = true;
          };
        };
        readAndSpeak = {
          typingFeedback = {
            characters = true;
            modifierKeys = false;
            selectionChanges = false;
            words = true;
          };
        };
        zoom = {
          useKeyboardShortcutsToZoom = false;
        };
      };
      desktopAndDock = {
        desktopAndStageManager = {
          clickWallpaperToRevealDesktop = "Only in Stage Manager";
        };
        # These five cover every key system.defaults.dock was writing: autohide,
        # show-recents, launchanim, orientation, and tilesize. show-recents had
        # two authors until this change, since showSuggestedAndRecentAppsInDock
        # is the same plist key that system.defaults.dock.show-recents wrote.
        dock = {
          automaticallyHideAndShowTheDock = {
            enabled = true;
          };
          animateOpeningApplications = true;
          dockPositionOnScreen = "Bottom";
          showSuggestedAndRecentAppsInDock = false;
          size = 48;
        };
        hotCorners = {
          bottomRight = {
            action = "Quick Note";
          };
        };
        missionControl = {
          shortcuts = {
            applicationWindows = "-";
            missionControl = "-";
            showDesktop = "-";
          };
        };
      };
      general = {
        autoFillAndPasswords = {
          deleteVerificationCodesAfterUse = false;
        };
        languageAndRegion = {
          preferredLanguages = [ "en-CA" ];
          region = "en_CA";
        };
        sharing = {
          mediaSharing = {
            shareMediaWithGuests = false;
          };
        };
      };
      keyboard = {
        # KeyRepeat and InitialKeyRepeat, the same two keys nix-darwin used to
        # write. Both take effect after the next login.
        delayUntilRepeat = 15;
        keyRepeatRate = 2;
        keyboardShortcuts = {
          accessibility = {
            decreaseContrast = false;
            increaseContrast = false;
            invertColors = false;
          };
          inputSources = {
            selectNextSourceInInputMenu = false;
            selectThePreviousInputSource = false;
          };
          missionControl = {
            moveLeftASpace = true;
            moveRightASpace = true;
          };
          spotlight = {
            showSpotlightSearch = false;
          };
        };
        textInput = {
          addPeriodWithDoubleSpace = true;
          capitalizeWordsAutomatically = true;
          # Canadian layout, matching the en-CA language and region below.
          inputSources = [ "com.apple.keylayout.Canadian" ];
        };
      };
      menuBar = {
        autoHideAndShowTheMenuBar = "Never";
        clock = {
          announceTheTime = {
            enable = false;
            interval = "On the hour";
          };
          showAmPm = true;
          showTheDayOfTheWeek = true;
        };
        textInput = false;
      };
      notifications = {
        notificationCenter = {
          summarizeNotifications = true;
        };
      };
      privacyAndSecurity = {
        appleAdvertising = {
          personalizedAds = false;
        };
      };
      sound = {
        soundEffects = {
          # com.apple.sound.beep.volume, formerly system.defaults.
          alertVolume = 0.0;
        };
      };
      trackpad = {
        pointAndClick = {
          click = "Medium";
        };
        scrollAndZoom = {
          rotate = true;
          zoomInOrOut = true;
        };
      };
    };
  };
}
