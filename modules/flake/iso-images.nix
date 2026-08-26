# Per-host NixOS installer ISOs.
#
# Exposes `nix build .#iso.<host>` (flake output `iso.<host>`), which is
# shorthand for `.#nixosConfigurations.<host>.config.system.build.isoImage`.
# Exactly ONE ISO variant (installer) per NixOS host: remembrance, antagony.
#
# Pending hosts (boot.state == "disabled") disable the initrd while awaiting
# enrollment, so their ISO variant must re-enable it to stay bootable. Enrolled
# hosts (boot.state == "uefi") keep the initrd at its default (enabled) and need
# no force.
#
# Every ISO carries the auto-enrollment tooling: a `hardware-enroll` oneshot
# runs on the booted installer, probes the real target hardware, and writes the
# reviewed candidate + RFC-6902 intake document under /root/enroll, idempotently
# overwriting any prior artifact for the host. The operator supplies the trust
# fixture at /root/enroll/trust.json (fail-closed without it). See
# `scripts/hardware/auto_enroll.py` and `config/hosts/intake/README.md`.
{ lib, config, ... }:
let
  authority = import ../entities/_machine-authority/model.nix;
  isoHosts = [ "remembrance" "antagony" ];

  isoFor = host:
    let
      machine = authority.getMachine host;
      needsInitrdForce = machine.boot.state == "disabled";
      baseDeclaration = builtins.toJSON machine;
      enrollment = { pkgs, ... }: {
        environment.systemPackages = [ (pkgs.callPackage ../../pkgs/enrollment-tooling.nix { }) ];
        systemd.services.hardware-enroll = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            mkdir -p /root/enroll
            ${pkgs.coreutils}/bin/printf '%s' '${baseDeclaration}' > /etc/hardware-enrollment/${host}.json
            nix-config-hardware-auto-enroll \
              --host ${host} \
              --base /etc/hardware-enrollment/${host}.json \
              --trust /root/enroll/trust.json \
              --out /root/enroll || true
          '';
        };
      };
    in
    (config.flake.nixosConfigurations.${host}.extendModules {
      modules =
        lib.optional needsInitrdForce { boot.initrd.enable = lib.mkForce true; }
        ++ [ enrollment ];
    }).config.system.build.images.iso;
in
{
  flake.iso = lib.genAttrs isoHosts isoFor;
}
