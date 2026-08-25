# deploy-rs wiring: day-2 deployment targets for the four hosts.
#
# Exposes `flake.deploy.nodes.<host>` (deploy-rs deploy configuration) and
# `flake.checks` (deployChecks) so `nix flake check --all-systems` validates
# the deploy topology without running any deployment.
#
# Hosts:
#   remembrance — NixOS x86_64-linux (this PC)
#   antagony    — NixOS x86_64-linux (ThinkPad P52)
#   entropy     — nix-darwin aarch64-darwin (Mac mini)
#   massive     — standalone-linux Home-Manager (CachyOS)
{ inputs, lib, ... }:
let
  inherit (inputs) self deploy-rs;
in
{
  flake.deploy.nodes.remembrance = {
    hostname = "remembrance";
    profiles.system = {
      user = "root";
      path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.remembrance;
    };
  };
  flake.deploy.nodes.antagony = {
    hostname = "antagony";
    profiles.system = {
      user = "root";
      path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.antagony;
    };
  };
  flake.deploy.nodes.entropy = {
    hostname = "entropy";
    profiles.system = {
      user = "root";
      path = deploy-rs.lib.aarch64-darwin.activate.darwin self.darwinConfigurations.entropy;
    };
  };
  flake.deploy.nodes.massive = {
    hostname = "massive";
    profiles.home = {
      user = "mei";
      path = deploy-rs.lib.x86_64-linux.activate.home-manager self.homeConfigurations.standalone-linux;
    };
  };
  # deployChecks: `nix flake check` validates the deploy topology (schema +
  # activation-script presence) without deploying anything.
  flake.checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
}