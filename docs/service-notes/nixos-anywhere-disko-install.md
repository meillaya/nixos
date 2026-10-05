# NixOS Disko install readiness boundary

> **Status:** `remembrance` carries a reviewed hardware enrollment
> (`config/hosts/intake/remembrance.json`); `antagony` is enrolled at install
> time by the one-command installer. A committed enrollment record is data, not
> authorization to erase a machine — the destructive gates below still apply.

The Task 7 slice defines a fail-closed boundary for a future attended Disko
install. It does not by itself provide a production disk writer; the shipped
install path drives the reviewed Disko layout through `nixos-anywhere` behind
the gates described in [`nixos-anywhere-iso-install.md`](./nixos-anywhere-iso-install.md).

The supported install path is ISO-first: one command on the target booted into
the flake ISO (`sudo nix run github:meillaya/nixos#install -- --yes`), or from
an operator machine `bin/host-install.sh --target-host <ip> --yes` / a manual
`nixos-anywhere --flake '.#<host>' --target-host root@<ip>`. The flake ISO sets
`VARIANT_ID=installer`, so `nixos-anywhere` skips kexec.

## Current guarantees

- `modules/nixos/disk-config.nix` is disabled by default and has no
  kernel-assigned or caller-substituted placeholder path.
- Enabling the layout requires an explicit host ID and a whole-device
  `/dev/disk/by-id/${diskBasename}` basename.
- The Task 7 readiness installer (`scripts/readiness/task7/installer.py`)
  rejects every non-fixture physical install with
  `physical-install-requires-attended-run`; that rejection is fixture-scoped.
  The live pipeline never writes a disk on its own either: `bin/host-install.sh`
  and the `install` app gate the destructive stage behind `--yes` (re-checked
  inside the stage), a reviewed enrollment record, and — in the app — a check
  that `/` is a live, RAM-backed root.
- The tool-sandbox record under `config/install/` is fixture data. Its zero NAR
  hashes are not release evidence and cannot authorize a real executable.

The attended confirmation contract is:

```text
ERASE <hostId> <diskById> <diskIdentitySha256> <deviceBindingSha256>
```

All four fields must be derived from the exact reviewed enrollment and the
boot-local descriptor facts. A basename alone is insufficient. A future
production implementation must revalidate size, logical sector size, sanitized
model/serial digests, canonical sysfs path, parent topology, major/minor, mount,
swap, and holder state before displaying this phrase and again before opening a
writer. The shipped installer does not implement this phrase yet; its gate is
`--yes` plus the reviewed enrollment, and it remains the required contract for a
future attended Disko writer.

## Safe fixture verification

The integrated readiness suite uses temporary JSON topology records and private
temporary directories. It never opens a real block device:

```bash
tests/readiness/run-task.sh 7 fixture
tests/readiness/run-task.sh 7 negative
tests/readiness/task7/test-static.sh
```

These results prove only the portable contracts and rejection behavior in the
tested checkout. They are not external hardware, provider, boot, or install
evidence.

## Future attended procedure

Do not run an install until a reviewed enrollment in the current machine model
binds all exact host and device facts — or let the one-command installer produce
exactly that enrollment from the live hardware before its gate. At that point the
supported entry point is the ISO-first flow: boot `.#iso.<host>` on the target
and use the `install` app or `nixos-anywhere` from the operator side. The
four-enrollment gate (`boot.state=uefi`, `storage.profile=single-gpt-btrfs`,
`publicTrust.state=enrolled`, `secretTrust.state=enrolled`) is the trust
boundary; the enrollment writers are the ISO/app auto-enrollment pipeline and
the KEPT hardware-intake validator (`bin/nix-config-hardware-intake create` +
`validate`).

Run the installer as root from the active local virtual terminal of a verified
installer image. Never run it through SSH, `sudo`, a terminal multiplexer,
`/dev/pts`, or with a kernel-assigned device path. Any mismatch or unavailable
enrollment must stop before a partitioning or formatting executable is invoked.

Do not call `disko-install`, `sfdisk`, or a filesystem formatter as a
workaround for the readiness slice; the supported live flow runs the reviewed
Disko layout through `nixos-anywhere`. Remote installation, provisioning
handoff, identity staging, reboot, rollback, and external qualification remain
outside this focused slice.

## What this slice does NOT do

- **`sweet` vendoring.** No longer deferred: `pkgs/sweet.nix` vendors the theme
  and `modules/linux/home-manager.nix` consumes it, so the earlier
  `gtk-engine-murrine` removal no longer breaks evaluation.
- **Per-host `nixos-anywhere` manifest signing.** The flow trusts the
  upstream `nixos-anywhere` release-signer-fingerprint verification. A
  custom sign step is a future addition.
- **Touching `~/nixos/`.** This slice is nixos only.
- **Bootstrapping the operator side.** Satisfied: `remembrance` is enrolled
  from its reviewed intake record, and `antagony` is enrolled at install time by
  the one-command installer. The repo still refuses physical installs until a
  reviewed enrollment binds all exact host + device facts.

## References

- <https://github.com/nix-community/disko/blob/master/docs/disko-install.md>
- <https://nix-community.github.io/nixos-anywhere/quickstart.html>
- <https://nix-community.github.io/nixos-anywhere/howtos/no-os.html>
- <https://github.com/viperML/nh>
- <https://nixos.org/manual/nixos/stable/>