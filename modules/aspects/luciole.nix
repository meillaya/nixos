# Native Wayland file manager from the Noctalia project. The application is
# Linux only, so the NixOS workstations and the standalone host include this
# aspect and the macOS host does not. The flake module installs its own package
# and writes the declarative base configuration; writable GUI overrides stay in
# ~/.config/luciole/settings.toml.
{ inputs, ... }:
let
  # The NixOS workstations receive Home Manager content from their users'
  # to-users providers; the standalone home applies the homeManager payload
  # directly. Both get the same module.
  module = {
    imports = [ inputs.luciole.homeModules.default ];

    programs.luciole.enable = true;
  };
in
{
  den.aspects.luciole = {
    provides.to-users.homeManager = module;
    homeManager = module;
  };
}
