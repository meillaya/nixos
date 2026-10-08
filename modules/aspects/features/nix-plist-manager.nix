{ den, inputs, ... }:
{
  # macOS settings live in one tool. nix-plist-manager names every option after
  # the control it writes and covers the System Settings panes, Finder, and the
  # general appearance keys that nix-darwin's system.defaults also writes. The
  # five keys both tools could set moved here, so each preference has one
  # author.
  den.aspects.nix-plist-manager = {
    darwin = {
      imports = [ inputs.nix-plist-manager.darwinModules.default ];

      programs.nix-plist-manager = {
        enable = true;
        options = import ../../darwin/mac-settings-system.nix;
      };
    };

    # The home-manager module is scoped here instead of on den.aspects.mei for
    # the same reason darwin-home is: the Linux hosts share that user aspect and
    # have no plists to write.
    provides.to-users.homeManager = {
      imports = [ inputs.nix-plist-manager.homeManagerModules.default ];

      programs.nix-plist-manager = {
        enable = true;
        options = import ../../darwin/mac-settings-user.nix;
      };
    };
  };
}
