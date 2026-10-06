# tests/iso-autostart-vm.nix — the gate-inertness VM (plan todo 14; the
# repo's first `pkgs.testers.runNixOSTest`).
#
# Boots the SAME extended configuration that `flake.isoConfig.<host>` exposes
# (the base host config plus the ISO-only enrollment / installer-marker /
# btrfs-support / autoinstall modules) as a QEMU test machine — both variants
# in ONE test run:
#
#   plainBoot  default kernel params: the opt-in gate must keep
#              `nixos-autoinstall.service` from ever activating, so a plain
#              boot touches nothing (no marker, no disk write).
#   gatedBoot  test-only `boot.kernelParams = [ "nixos.autoinstall=1" ]`:
#              the unit runs, fails, and the failure activates the rescue
#              target. No install is ever started: this `=1` flag exists only
#              inside this test, never as a boot default (wiring a full `=1`
#              install run into the flake checks stays a deliberate manual
#              step, per the plan's Must-NOT).
#
# Shipped-config finding (observed in this VM, recorded not fixed here): the
# gated unit cannot yet get as far as the install app. Its service PATH (the
# systemd module default: coreutils/findutils/gnugrep/gnused/systemd) lacks
# `bash`, so the app wrapper (`#!/usr/bin/env bash`) dies with
# "env: 'bash': No such file or directory" (status 127). With bash added, the
# next blocker is the missing `nix` on the same PATH (`nix eval` is the app's
# first action). The real ISO carries the same unit and PATH, so its autostart
# is equally non-functional; this test asserts what ships today — the gate
# opens, the unit's start script runs and fails cleanly, the rescue target
# takes over, and nothing is written — and keeps passing once the unit is
# repaired and the app's own host-match guard becomes the failure it reaches.
#
# `node.pkgsReadOnly = false` keeps the shared-policy `nixpkgs.config` /
# `overlays` that the imported modules define; the read-only-pkgs shortcut
# would reject those definitions. Node disk space comes from the qemu-vm
# module defaults; the extra empty disk is the "nothing was written" witness.
#
# Two test-only fixtures keep the VM faithful and bootable (documented in the
# let-block below): an installed machine's bootstrap-password verifier, which
# the ISO config's activation validator demands even on a fresh boot, and
# memory/cores matched to the full workstation closure the ISO config carries.
{ pkgs, isoConfig }:
let
  # Test-only fixture 1: a throwaway yescrypt verifier for the VM's account.
  # The ISO config's activation validator (modules/nixos/bootstrap-password.nix)
  # fails any fresh machine without /var/lib/nixos-bootstrap/mei-password.hash,
  # and the config's systemd initrd runs activation before switch-root, so a
  # fresh boot never reaches stage 2 (observed: switch-root fails with
  # "os-release file is missing", then the test framework's panic-on-fail kills
  # the VM). Installed machines carry exactly this file, staged by the
  # installer; seeding it here reproduces the installed machine's first boot.
  bootstrapHash = "$y$j9T$2Et07t.7WMkmGGTiT3n2I0$RYWTdy.Dy3EYwq5ySiGBDOc8MYLoDxEMOE2m9QLxeQ5";

  vmFixture =
    { pkgs, ... }:
    {
      # Test-only fixture 2: resource fit. The imported config is a full
      # workstation closure; the qemu-vm 1 GiB / 1 CPU defaults are too small
      # for it under the test driver.
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;

      # Seed the verifier into the real root before the initrd's activation
      # runs, so the validator sees what an installed system would carry.
      boot.initrd.systemd.services.seed-bootstrap-password = {
        description = "Seed the bootstrap password hash fixture for the gate-inertness VM";
        unitConfig.DefaultDependencies = false;
        after = [ "sysroot.mount" ];
        before = [ "initrd-nixos-activation.service" ];
        wantedBy = [ "initrd-nixos-activation.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.coreutils}/bin/install -d -o 0 -g 0 -m 0700 /sysroot/var/lib/nixos-bootstrap
          ${pkgs.coreutils}/bin/printf '%s\n' '${bootstrapHash}' > /sysroot/var/lib/nixos-bootstrap/mei-password.hash
          ${pkgs.coreutils}/bin/chown 0:0 /sysroot/var/lib/nixos-bootstrap/mei-password.hash
          ${pkgs.coreutils}/bin/chmod 0600 /sysroot/var/lib/nixos-bootstrap/mei-password.hash
        '';
      };
    };
in
pkgs.testers.runNixOSTest {
  name = "iso-autostart-vm";

  # The imported modules define nixpkgs.config/overlays (shared-policy), so the
  # documented escape hatch from the read-only pkgs shortcut applies.
  node.pkgsReadOnly = false;

  nodes = {
    plainBoot = {
      imports = isoConfig.type.getSubModules ++ [ vmFixture ];
      virtualisation.emptyDiskImages = [ 32 ];
    };
    gatedBoot = {
      imports = isoConfig.type.getSubModules ++ [ vmFixture ];
      boot.kernelParams = [ "nixos.autoinstall=1" ];
      virtualisation.emptyDiskImages = [ 32 ];
    };
  };

  testScript = ''
    def assert_untouched_data_disk(machine):
        # Exactly one extra (empty) data disk is attached besides the root
        # disk; neither boot may have formatted it or written a signature.
        disks = machine.succeed("lsblk -ndo NAME,TYPE | awk '$2==\"disk\" {print $1}'").split()
        data = [d for d in disks if d != "vda"]
        assert len(data) == 1, f"expected exactly one data disk besides vda, got {disks!r}"
        machine.succeed(f"test -z \"$(blkid -o value -s TYPE /dev/{data[0]} 2>/dev/null)\"")

    start_all()

    # ---- variant (a): a plain boot stays inert ------------------------------
    plainBoot.wait_for_unit("multi-user.target")

    # The gate is a per-boot kernel-command-line condition: systemd skipped the
    # unit (ConditionResult=no) and nothing ever started it.
    plainBoot.succeed("test \"$(systemctl show -p ActiveState --value nixos-autoinstall.service)\" = inactive")
    plainBoot.succeed("test \"$(systemctl show -p ConditionResult --value nixos-autoinstall.service)\" = no")

    # The failure path (rescue target) never ran either.
    plainBoot.succeed("test \"$(systemctl show -p ActiveState --value iso-install-rescue.target)\" = inactive")

    # A plain boot touches nothing.
    plainBoot.succeed("test ! -e /run/autoinstall-done")
    assert_untouched_data_disk(plainBoot)
    print("plainBoot lsblk:")
    print(plainBoot.succeed("lsblk"))

    # ---- variant (b): the per-boot opt-in opens the gate --------------------
    gatedBoot.wait_for_unit("multi-user.target")

    # The condition was satisfied and the unit actually ran...
    gatedBoot.succeed("test \"$(systemctl show -p ConditionResult --value nixos-autoinstall.service)\" = yes")
    # ... and failed cleanly by exit status (no hang, no crash loop, no
    # dependency failure).
    gatedBoot.wait_until_succeeds("systemctl is-failed nixos-autoinstall.service")
    gatedBoot.succeed("test \"$(systemctl show -p Result --value nixos-autoinstall.service)\" = exit-code")
    gatedBoot.wait_for_unit("iso-install-rescue.target")

    # No install artifact and no disk write.
    gatedBoot.succeed("test ! -e /run/autoinstall-done")
    assert_untouched_data_disk(gatedBoot)

    # The journal shows the unit's start script actually ran (its output is
    # prefixed with the script's syslog identifier, whatever it reports).
    print("nixos-autoinstall.service journal:")
    print(gatedBoot.succeed("journalctl -u nixos-autoinstall.service --no-pager"))
    gatedBoot.succeed("journalctl -u nixos-autoinstall.service --no-pager | grep -F 'nixos-autoinstall-start'")
  '';
}
