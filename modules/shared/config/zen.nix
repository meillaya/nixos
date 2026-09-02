# Shared declarative Zen Browser configuration — GENERATED from the live
# profile at ~/.config/zen/wqidnanv.Default Profile (zen-sessions.jsonlz4 + prefs.js).
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

    profiles.default = {
      # Target the real browser profile dir (not a fresh "default").
      path = "wqidnanv.Default Profile";

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

      # Real pinned tabs, each tied to its real space by workspace id.
      # pinsForce + demote: reproduces all 28 real pins; any future undeclared
      # pin is kept as a normal tab rather than deleted (lossless parity).
      pinsForce = true;
      pinsForceAction = "demote";
      pins = {
        "P01" = {
          id = "1784424664279-59";
          url = "https://x.com/home";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # Home / X
        };
        "P02" = {
          id = "1784256692792-100";
          url = "https://www.kimi.ai/design";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # Kimi Design | From idea to artifact
        };
        "P03" = {
          id = "1784256692822-24";
          url = "https://chatgpt.com/c/6a57f3bd-41ac-83ea-9631-fdf12b055781";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # Embedded Systems Project
        };
        "P04" = {
          id = "1784256692822-13";
          url = "https://auth.primeintellect.ai/u/login/identifier?state=hKFo2SBoeWFIbGJWQzZ2SDRhMXg1ZlJnX2cxYVZaOXh5ZUQ4dqFur3VuaXZlcnNhbC1sb2dpbqN0aWTZIDVQZHR4eHhRN2VFV1UwOGdobjJaRUhfRElXYVEyQXoxo2NpZNkgY3ZLTGdJZ1B0SnNtcGJWSVYwQUlaUmdtMVpseFFwdlA";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # Log in | Compute Platform
        };
        "P05" = {
          id = "1784256692823-11";
          url = "https://modal.com/endpoints/meillaya/main";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # Endpoints - meillaya | Modal
        };
        "P06" = {
          id = "1784256692823-22";
          url = "https://openrouter.ai/settings/credits";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # Credits | OpenRouter
        };
        "P07" = {
          id = "1784390348270-52";
          url = "https://opencode.ai/workspace/wrk_01KE7J3E0BFJH07NZS8W196DPJ/keys";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # opencode
        };
        "P08" = {
          id = "1785433327846-43";
          url = "https://signin.aws.amazon.com/signin?redirect_uri=https%3A%2F%2Fus-east-1.console.aws.amazon.com%2Fconsole%2Fhome%3Fca-oauth-flow-id%3Da646%26hashArgs%3D%2523%26isauthcode%3Dtrue%26region%3Dus-east-1%26state%3DhashArgsFromTB_us-east-1_ea01366d57b9911c&client_id=arn%3Aaws%3Asignin%3A%3A%3Aconsole%2Fcanvas&forceMobileApp=0&oauth_region=us-east-1&code_challenge=8iMHqjk1eNhBM5Sviy99ARmztSz55gquaA1Yl-YOaCI&code_challenge_method=SHA-256";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # Amazon Web Services Sign-In
        };
        "P09" = {
          id = "1784426068478-18";
          url = "https://chat.deepseek.com/a/chat/s/3ca1a216-9eb3-4f1a-8cd4-dc41ae235b54";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # Cordless PC Build Guide - DeepSeek
        };
        "P10" = {
          id = "1785173192338-79";
          url = "https://huggingface.co/";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # Hugging Face – The AI community building the future.
        };
        "P11" = {
          id = "1788346200558-52";
          url = "https://app.machine0.io/images";
          workspace = "d46a1a4d-05e0-42a1-aa6e-999f43d3c90f";  # Dev
          # machine0
        };
        "P12" = {
          id = "1784265461859-89";
          url = "https://app.tuta.com/mail/Olwds23-1s-9/OvbckSR--3-9?mail";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
          # illiandre@tuta.com - Tuta Mail: Login & Sign up for free
        };
        "P13" = {
          id = "1784265502295-61";
          url = "https://mail.proton.me/u/1/inbox/0t63lr3YN46cOr5fM4JscMpSscyvi1YAGzpafCnk-THJYxYJXumWreHEToIpvpyTeqM98kPqMsneQegPgO787g==#category=primary";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
          # (2) Inbox | desilute@proton.me | Proton Mail
        };
        "P14" = {
          id = "1785475399569-66";
          url = "https://play.google.com/books";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
          # Google Play Books
        };
        "P15" = {
          id = "1788170823590-87";
          url = "https://annas-archive.gl/";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
          # Anna’s Archive: LibGen (Library Genesis), Sci-Hub, Z-Library in one place - Anna’s Archive
        };
        "P16" = {
          id = "1788356396589-79";
          url = "about:blank";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
        };
        "P17" = {
          id = "1788251317428-54";
          url = "https://duckduckgo.com/?t=ffab&q=yeston+sakura&ia=web";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
          # yeston sakura at DuckDuckGo
        };
        "P18" = {
          id = "1788251170193-96";
          url = "https://duckduckgo.com/?t=ffab&q=Nollie+8&ia=web";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
          # Nollie 8 at DuckDuckGo
        };
        "P19" = {
          id = "1788251260200-11";
          url = "https://starforgesystems.com/collections/plate-lights";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
          # Platelight Panels– Starforge Systems
        };
        "P20" = {
          id = "1788250961375-45";
          url = "https://ca.pcpartpicker.com/user/Xcryus/saved/";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
          # Xcryus - Saved Part Lists - PCPartPicker
        };
        "P21" = {
          id = "1787112234472-19";
          url = "https://ca.pcpartpicker.com/products/memory/#sort=-rating&page=1";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
          # Choose Memory - PCPartPicker
        };
        "P22" = {
          id = "1788346833594-79";
          url = "https://duckduckgo.com/?t=ffab&q=custom+loop+pc+build&ia=web";
          workspace = "66b75881-fbf4-40c5-95de-ac8041642aad";  # Personal
          # custom loop pc build at DuckDuckGo
        };
        "P23" = {
          id = "1784257380111-76";
          url = "https://www.overleaf.com/project";
          workspace = "cf68abf2-8397-4a1a-9304-f3d0c5354597";  # Work
          # Your projects - Overleaf, Online LaTeX Editor
        };
        "P24" = {
          id = "1784257391388-70";
          url = "https://foxinthetruck.com/login";
          workspace = "cf68abf2-8397-4a1a-9304-f3d0c5354597";  # Work
          # Fox In The Truck - Construction Waste Management
        };
        "P25" = {
          id = "1784257413980-86";
          url = "https://railway.com/dashboard";
          workspace = "cf68abf2-8397-4a1a-9304-f3d0c5354597";  # Work
          # Railway
        };
        "P26" = {
          id = "1784262078147-100";
          url = "https://github.com/meillaya/nixos";
          workspace = "cf68abf2-8397-4a1a-9304-f3d0c5354597";  # Work
          # meillaya/nixos: Multi-system Nix/NixOS configs.
        };
        "P27" = {
          id = "1786302197909-72";
          url = "https://resend.com/emails/b1fa5858-d5f2-497a-a654-0c1daa31fd3a";
          workspace = "cf68abf2-8397-4a1a-9304-f3d0c5354597";  # Work
          # foxinthetruck@gmail.com · Emails · Resend
        };
        "P28" = {
          id = "1787066076673-74";
          url = "https://hiraeth.up.railway.app/publishers/unnamed-press";
          workspace = "cf68abf2-8397-4a1a-9304-f3d0c5354597";  # Work
          # Publisher · Hiraeth
        };
      };

      # Live keyboard-shortcut schema version (prevents silent breakage).
      keyboardShortcutsVersion = 20;
    };
  };
}
