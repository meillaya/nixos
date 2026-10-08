# deploy-rs wiring: day-2 deployment targets for the four hosts.
#
# Exposes `flake.deploy.nodes.<host>` (deploy-rs deploy configuration) and
# `flake.checks` (deployChecks) so `nix flake check --all-systems` validates
# the deploy topology without running any deployment.
#
# Hosts:
#   remembrance: NixOS x86_64-linux (this PC)
#   antagony   : NixOS x86_64-linux (ThinkPad P52)
#   entropy    : nix-darwin aarch64-darwin (Mac mini)
#   massive    : standalone Home-Manager host (CachyOS); Home Manager owns the
#                user payload and system-manager owns hostname and services
{ inputs, lib, ... }:
let
  inherit (inputs) self deploy-rs;
  # Only the systems this flake builds (see the comment at flake.checks):
  # deploy-rs also advertises aarch64-linux and x86_64-darwin, and evaluating
  # the latter aborts under the current nixpkgs pin.
  supportedDeployLibs =
    lib.filterAttrs
      (system: _: builtins.elem system [ "x86_64-linux" "aarch64-darwin" ])
      deploy-rs.lib;
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
      path = deploy-rs.lib.x86_64-linux.activate.home-manager self.homeConfigurations.massive;
    };
  };
  # deployChecks: `nix flake check` validates the deploy topology (schema +
  # activation-script presence) without deploying anything. Only the systems
  # this flake builds are checked: deploy-rs also advertises aarch64-linux and
  # x86_64-darwin, and evaluating the latter against the current nixpkgs pin
  # aborts ("Nixpkgs 26.11 has dropped support for x86_64-darwin"), which
  # takes the whole checks tree down with it.
  flake.checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) supportedDeployLibs;
}