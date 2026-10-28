{ inputs, lib, ... }:
let
  nixpkgsPolicy = import ../../lib/nixpkgs.nix { inherit inputs; };
  identityType = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      home = lib.mkOption { type = lib.types.str; };
      uid = lib.mkOption { type = lib.types.ints.unsigned; };
      gid = lib.mkOption { type = lib.types.ints.unsigned; };
    };
  };
in
{
  den.schema.user = {
    options.identity = lib.mkOption {
      type = identityType;
      description = "Account identity attached to a user entity.";
    };
    config.classes = lib.mkDefault [ "homeManager" ];
  };

  den.schema.aspect.options = {
    nixos = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
      description = "NixOS class module owned by an aspect.";
    };
    darwin = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
      description = "Darwin class module owned by an aspect.";
    };
    homeManager = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
      description = "Home Manager class module owned by an aspect.";
    };
  };

  den.schema.home =
    { home, ... }:
    {
      options.homeDirectory = lib.mkOption {
        type = lib.types.str;
        description = "Absolute home directory for a standalone Home Manager entity.";
      };

      config.pkgs = nixpkgsPolicy.mkPkgs home.system;
    };
}
