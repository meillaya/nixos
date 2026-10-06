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
# Shipped-config finding (observed in this VM). The unit's service PATH now
# carries the interpreter, the shebang's env, and nix
# (`path = [ pkgs.bash pkgs.coreutils pkgs.nix ]` in modules/flake/iso-images.nix),
# so the app wrapper runs: the journal shows its "Running install for
# x86_64-linux" banner and the app's own `install:` diagnostic. The app cannot
# get as far as its host-match guard *here* only because its first action is
# `nix eval` of the baked flake, which must resolve the flake's inputs, and this
# test's Nix build sandbox has no network (observed: the unit blocked ~25s on
# 282ms CPU / 7.1K outgoing IP before the eval gave up). On real hardware the
# unit's `after network-online.target` supplies that network and the app
# proceeds to the host-match check. This test therefore pins the reachable
# observable — the app starts and emits its own diagnostic — which fails
# whenever the unit PATH regresses (a 127 leaves neither line). The gate
# itself is still what this test proves: a plain boot activates nothing.
#
# `node.pkgsReadOnly = false` keeps the shared-policy `nixpkgs.config` /
# `overlays` that the imported modules define; the read-only-pkgs shortcut
# would reject those definitions. Node disk space comes from the qemu-vm
# module defaults; the extra empty disk is the "nothing was written" witness.
#
# The only test-only fixture left is the resource fit (memory/cores matched to
# the full workstation closure the ISO config carries). A bootstrap-password seed
# fixture was removed in todo 16: the ISO variant now neutralizes its own
# bootstrap-password verifier (see modules/flake/iso-images.nix), so this VM
# boots the config AS SHIPPED and any regression there fails the test.
{ pkgs, isoConfig }:
let
  vmFixture =
    { pkgs, ... }:
    {
      # Test-only fixture: resource fit. The imported config is a full
      # workstation closure; the qemu-vm 1 GiB / 1 CPU defaults are too small
      # for it under the test driver. No activation fixture is needed: the ISO
      # variant neutralizes its own bootstrap-password verifier (see
      # modules/flake/iso-images.nix), so this VM boots the config as shipped.
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;
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

    # The journal shows the app actually started, not merely that the unit's
    # start script was invoked: the wrapper's banner prints only once
    # `#!/usr/bin/env bash` resolves, and `install: ` is the app's own
    # diagnostic. Under the F-B breakage (a service PATH without bash) the unit
    # died at 127 and neither line appeared, so both assertions fail on the
    # regression they name. The host-match guard is not reachable in this
    # offline sandbox (see the header).
    print("nixos-autoinstall.service journal:")
    print(gatedBoot.succeed("journalctl -u nixos-autoinstall.service --no-pager"))
    gatedBoot.succeed("journalctl -u nixos-autoinstall.service --no-pager | grep -F 'Running install for x86_64-linux'")
    gatedBoot.succeed("journalctl -u nixos-autoinstall.service --no-pager | grep -F 'install: '")
  '';
}
