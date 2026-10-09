# Per-host NixOS installer ISOs.
#
# Exposes `nix build .#iso.<host>` (flake output `iso.<host>`), which is
# shorthand for `.#nixosConfigurations.<host>.config.system.build.isoImage`,
# built from the extended per-host config `flake.isoConfig.<host>`.
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
#
# A plain boot is inert. When the operator appends `nixos.autoinstall=1` at the
# boot menu, `nixos-autoinstall.service` runs the flake's own install app for
# this host; a failure activates `iso-install-rescue.target`, which drops to a
# root shell on tty1. The flag is never added to `boot.kernelParams`, so no
# automatic path can start an install.
#
# The image also declares itself a NixOS installer (`VARIANT_ID=installer`), so
# nixos-anywhere skips its kexec phase. Without the marker a one-command
# self-install (nixos-anywhere runs on the same machine through root@127.0.0.1)
# would kexec out from under its own orchestrating process.
{ inputs, lib, config, ... }:
let
  authority = import ../aspects/_machine-authority/model.nix;
  isoHosts = [ "remembrance" "antagony" ];

  isoConfigFor = host:
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
            nix-config-hardware-auto-enroll \
              --host ${host} \
              --base /etc/hardware-enrollment/${host}.json \
              --trust /root/enroll/trust.json \
              --out /root/enroll || echo "hardware-enroll: masked failure (artifact presence is the gate)" >&2
          '';
        };
        # The base record the oneshot's `--base` reads must already exist at boot:
        # land it declaratively instead of racing a runtime write inside the unit.
        environment.etc."hardware-enrollment/${host}.json".text = baseDeclaration;
      };
      installerMarker = {
        system.nixos.variant_id = "installer";
      };
      # Installer-only: the target disk carries btrfs subvolumes (see
      # `modules/nixos/disk-config.nix`), so the ISO must be able to mount and
      # inspect it. The installer profile drops btrfs from the supported set;
      # re-add the filesystems and load the module at boot.
      btrfsSupport = {
        boot.supportedFilesystems = [ "btrfs" "vfat" ];
        boot.kernelModules = [ "btrfs" ];
      };
      autoinstall = { pkgs, ... }: {
        # Bake the flake tree at a stable path so a booted installer can drive
        # another install by hand without fetching anything. The unit below
        # runs the app wrapper, whose closure carries the same source.
        environment.etc."nixos-install/flake".source = "${inputs.self}";

        # Opt-in autostart: the unit activates ONLY when the operator appends
        # `nixos.autoinstall=1` at the boot menu (ConditionKernelCommandLine).
        # The marker check stops a second attempt within the same boot, and a
        # failure lands in the rescue target instead of a reboot loop.
        systemd.services.nixos-autoinstall = {
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" "sshd.service" "hardware-enroll.service" ];
          unitConfig = {
            ConditionKernelCommandLine = "nixos.autoinstall=1";
            ConditionPathExists = "!/run/autoinstall-done";
            SuccessAction = "reboot";
            OnFailure = [ "iso-install-rescue.target" ];
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            StandardOutput = "journal+console";
            StandardError = "journal+console";
          };
          # The app wrapper is `#!/usr/bin/env bash` and the app's first action
          # is `nix eval` (the wrapper then puts its own tool closure on PATH);
          # the systemd default service PATH carries neither, so the unit died
          # with `env: 'bash': No such file or directory` (status 127) before
          # the app could run. Give it the interpreter, the env shebang's
          # coreutils, and nix.
          path = [ pkgs.bash pkgs.coreutils pkgs.nix ];
          script = ''
            ${config.flake.apps.x86_64-linux.install.program} --host ${host} --yes --rescue-identity
          '';
        };

        systemd.targets.iso-install-rescue = {
          description = "ISO auto-install rescue (the install attempt failed)";
        };

        # The rescue target hands the operator a root shell on tty1; tty-force
        # takes the tty from the getty so the shell owns the console.
        systemd.services.iso-install-rescue-shell = {
          description = "ISO auto-install rescue shell on tty1";
          wantedBy = [ "iso-install-rescue.target" ];
          serviceConfig = {
            Type = "idle";
            ExecStart = "${pkgs.bashInteractive}/bin/bash -i";
            StandardInput = "tty-force";
            StandardOutput = "tty";
            StandardError = "tty";
            TTYPath = "/dev/tty1";
            TTYReset = true;
            TTYVHangup = true;
            TTYVTDisallocate = true;
          };
        };
      };
      # Installer-only: the live ISO's "/" is a fresh tmpfs, so the bootstrap
      # password verifier cannot find /var/lib/nixos-bootstrap/<user>-password.hash
      # at activation time. With systemd's initrd, `initrd-nixos-activation`
      # runs EVERY activation script before switch-root, so the verifier's
      # hard-fail aborts the boot and switch-root then refuses ("os-release file
      # is missing") -> emergency mode (F-A diagnosis). Neutralize both
      # bootstrap-password activation scripts on the installer variant only; the
      # installed system (and this variant's `users` activation, which merely
      # warns when `hashedPasswordFile` is absent under mutableUsers) keeps
      # the validators intact.
      bootstrapPasswordInert =
        let
          inert = {
            deps = [ ];
            text = "";
          };
        in
        {
          system.activationScripts.bootstrapPasswordHash = lib.mkForce inert;
          system.activationScripts.consumeBootstrapPassword = lib.mkForce inert;
        };
    in
    (config.flake.nixosConfigurations.${host}.extendModules {
      modules =
        lib.optional needsInitrdForce { boot.initrd.enable = lib.mkForce true; }
        ++ [ enrollment installerMarker btrfsSupport autoinstall bootstrapPasswordInert ];
    });
in
{
  flake.isoConfig = lib.genAttrs isoHosts isoConfigFor;
  flake.iso = lib.genAttrs isoHosts (host: config.flake.isoConfig.${host}.config.system.build.images.iso);
}
