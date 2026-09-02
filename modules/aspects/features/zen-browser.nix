# Declarative Zen Browser via the zen-browser-flake Home-Manager module.
#
# One shared fragment (modules/shared/config/zen.nix) drives identical spaces,
# pinned tabs, settings, policies, and shortcuts on every host that selects
# this aspect, so the same tabs/spaces reproduce across machines without
# profile-folder copying (profiles are machine-InstallID-bound).
{ inputs, ... }:
{
  den.aspects.zen-browser.homeManager =
    { config, ... }:
    {
      imports = [
        inputs.zen-browser.homeModules.beta
        (import ../../shared/config/zen.nix)
      ];
    };
}