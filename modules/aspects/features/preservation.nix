{ inputs, ... }:
{
  den.aspects.preservation = {
    nixos = { pkgs, ... }: {
      imports = [ inputs.preservation.nixosModules.default ];

      # preservation only exposes a nixosModule (no packages or apps);
      # the CLI ships separately via `nix-community/preservation-cli`
      # if/when the operator installs it. `preserveAt` is an attrset
      # keyed by path with submodule options (directories / files /
      # users.*); leave it absent here and let each per-host
      # `modules/aspects/named-hosts/*.nix` add the entries it actually
      # needs. `enable = true` is enough to wire the systemd mount-unit
      # machinery; the operator picks what to preserve per host.
      preservation.enable = true;
    };
  };
}
