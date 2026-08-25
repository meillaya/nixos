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
  bootType = lib.types.submodule {
    options = {
      state = lib.mkOption {
        type = lib.types.enum [ "disabled" "uefi" ];
      };
      secureBoot = lib.mkOption { type = lib.types.bool; };
      configurationLimit = lib.mkOption { type = lib.types.ints.positive; };
    };
  };
  storageExpectationType = lib.types.submodule {
    options = {
      sizeBytes = lib.mkOption { type = lib.types.ints.positive; };
      logicalSectorBytes = lib.mkOption {
        type = lib.types.enum [ 512 4096 ];
      };
      modelSha256 = lib.mkOption { type = lib.types.str; };
      serialSha256 = lib.mkOption { type = lib.types.str; };
    };
  };
  storageType = lib.types.submodule {
    options = {
      profile = lib.mkOption {
        type = lib.types.enum [ "none" "single-gpt-btrfs" ];
      };
      diskById = lib.mkOption { type = lib.types.str; };
      expected = lib.mkOption { type = storageExpectationType; };
    };
  };
  capabilityValueType = lib.types.submodule {
    options = {
      state = lib.mkOption {
        type = lib.types.enum [ "present" "absent" ];
      };
      reason = lib.mkOption {
        type = lib.types.enum [ "not-equipped" "unsupported" "deferred" ];
      };
    };
  };
  capabilitiesType = lib.types.submodule {
    options = {
      state = lib.mkOption {
        type = lib.types.enum [ "disabled" "enrolled" ];
      };
      values = lib.mkOption {
        type = lib.types.attrsOf capabilityValueType;
      };
    };
  };
  machineType = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.raw;
    options = {
      hostId = lib.mkOption { type = lib.types.str; };
      target = lib.mkOption { type = lib.types.str; };
      system = lib.mkOption {
        type = lib.types.enum [ "x86_64-linux" "aarch64-darwin" ];
      };
      role = lib.mkOption {
        type = lib.types.enum [ "workstation" "qualifier" "evaluation" ];
      };
      identity = lib.mkOption { type = identityType; };
      boot = lib.mkOption { type = bootType; };
      storage = lib.mkOption { type = storageType; };
      capabilities = lib.mkOption { type = capabilitiesType; };
      remoteInstall = lib.mkOption { type = lib.types.bool; };
    };
  };
in
{
  den.schema.user = {
    options.identity = lib.mkOption {
      type = identityType;
      description = "Validated account identity attached to a user entity.";
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
      description = "nix-darwin class module owned by an aspect.";
    };
    homeManager = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
      description = "Home Manager class module owned by an aspect.";
    };
  };

  den.schema.flake.options.machineAuthority = lib.mkOption {
    type = lib.types.raw;
    description = "Validated machine identity and capability authority.";
  };

  den.schema.host.options.machine = lib.mkOption {
    type = machineType;
    description = "Structurally typed, validated machine data attached to a host entity.";
  };

  den.schema.home =
    { home, ... }:
    {
      options.homeDirectory = lib.mkOption {
        type = lib.types.str;
        description = "Absolute home directory for a standalone Home Manager entity.";
      };
      options.machine = lib.mkOption {
        type = machineType;
        description = "Structurally typed, validated machine data attached to a standalone home entity.";
      };

      config.pkgs = nixpkgsPolicy.mkPkgs home.system;
    };
}
