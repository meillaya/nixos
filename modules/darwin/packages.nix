{ pkgs }:

with pkgs;
let
  shared-packages = import ../shared/packages.nix { inherit pkgs; includeDocker = false; };

  # nixpkgs' cythonDebugSpeedupsHook looks for `plugins/python*/helpers/pydev`
  # at the unpack root. A Darwin DMG unpacks a `PyCharm.app` bundle instead, so
  # the hook finds no setup_cython.py and preInstall fails with exit code 2.
  # Dropping the hook leaves PyCharm on the pure-Python debugger. Remove this
  # override once nixpkgs reads the bundle layout.
  pycharm = jetbrains.pycharm.overrideAttrs (old: {
    nativeBuildInputs = lib.subtractLists [ jetbrains.cythonDebugSpeedupsHook ] (old.nativeBuildInputs or [ ]);
  });
in
shared-packages ++ [
  # App replacements formerly installed as casks
  bruno
  dbeaver-bin
  ghostty-bin
  iterm2
  jetbrains.idea
  kitty
  postman
  vesktop
  raycast

  # tailscale is deliberately absent here: modules/darwin/base.nix enables
  # services.tailscale, which installs the package itself and runs the daemon.

  # Development tools
  cocoapods
  dockutil
  helix
  micro
  neovim
  omniorb
  (pkgs.callPackage ../../pkgs/omniwm.nix { })
  pycharm
  uv
]
