# Boot the live profile with an extra blank disk and run the installer's disk
# phase against it. No system is installed: --test stops after the label,
# filesystem, and mount checks, so the test is fast and leaves the root disk
# alone.
{ pkgs, liveConfig }:
let
  vmFixture =
    { lib, ... }:
    {
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;
      virtualisation.emptyDiskImages = [ 32 ];
      virtualisation.useBootLoader = true;
      virtualisation.useEFIBoot = true;
      # The live profile defaults to a tmpfs root; the VM owns a real root.
      fileSystems."/".device = lib.mkForce "/dev/vda";
      fileSystems."/".fsType = lib.mkForce "ext4";
    };
in
pkgs.testers.runNixOSTest {
  name = "installer-disk-vm";
  node.pkgsReadOnly = false;

  nodes.installer = {
    imports = liveConfig.type.getSubModules ++ [ vmFixture ];
  };

  testScript = ''
    start_all()
    installer.wait_for_unit("multi-user.target")

    output = installer.succeed(
        "nixos-install-tui --test --disk /dev/vdb --yes --non-interactive"
    )
    assert "NIXBOOT" in output, output
    assert "NIXROOT" in output, output
    assert "@root" in output, output
    assert "@home" in output, output
    assert "@nix" in output, output
    assert "@log" in output, output

    installer.succeed("blkid -o value -s LABEL /dev/vdb1 | grep -Fx NIXBOOT")
    installer.succeed("blkid -o value -s LABEL /dev/vdb2 | grep -Fx NIXROOT")
    installer.succeed("lsblk -o NAME,LABEL,PARTLABEL /dev/vdb")
  '';
}
