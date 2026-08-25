# NixOS Disko install readiness boundary

> **Not production-enrolled:** this repository currently contains no reviewed
> physical host or disk enrollment. The committed records and readiness cases
> are synthetic fixtures, not authorization to erase a machine.

The Task 7 slice defines a fail-closed boundary for a future attended Disko
install. It does not make remote installation ready and it does not provide a
working production disk writer.

The supported install path is the ISO-first flow documented in
[`nixos-anywhere-iso-install.md`](./nixos-anywhere-iso-install.md): build a
per-host installer ISO (`nix build .#iso.<host>`), boot it on the target, and
run `nixos-anywhere` with `--flake '.#<host>' --target-host root@<ip>`. The
ISO sets `VARIANT_ID=installer`, so `nixos-anywhere` skips kexec.

## Current guarantees

- `modules/nixos/disk-config.nix` is disabled by default and has no
  kernel-assigned or caller-substituted placeholder path.
- Enabling the layout requires an explicit host ID and a whole-device
  `/dev/disk/by-id/${diskBasename}` basename.
- The hardware-intake validator (`bin/nix-config-hardware-intake`) rejects
  every non-fixture physical install. The final
  `physical-install-requires-attended-run` rejection is deliberate until a
  production enrollment source is wired to the current host architecture.
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
writer.

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
binds all exact host and device facts. At that point the supported entry point
is the ISO-first flow: build `.#iso.<host>`, boot it on the target, and run
`nixos-anywhere` from the operator side. The four-enrollment gate
(`boot.state=uefi`, `storage.profile=single-gpt-btrfs`,
`publicTrust.state=enrolled`, `secretTrust.state=enrolled`) is the trust
boundary; the enrollment writer is the KEPT hardware-intake validator
(`bin/nix-config-hardware-intake create` + `validate`).

Run the installer as root from the active local virtual terminal of a verified
installer image. Never run it through SSH, `sudo`, a terminal multiplexer,
`/dev/pts`, or with a kernel-assigned device path. Any mismatch or unavailable
enrollment must stop before a partitioning or formatting executable is invoked.

Do not call `disko-install`, `sfdisk`, or a filesystem formatter as a
workaround. Remote installation, provisioning handoff, identity staging,
reboot, rollback, and external qualification remain outside this focused slice.

## What this slice does NOT do

- **Vendoring `sweet`.** Still deferred per the earlier revert; out of
  scope here. Until `pkgs.sweet` is provided, every NixOS toplevel
  eval and standalone-Linux home activation in this repo fails with
  `'sweet' has been removed because it depended on 'gtk-engine-murrine'`.
- **Per-host `nixos-anywhere` manifest signing.** The flow trusts the
  upstream `nixos-anywhere` release-signer-fingerprint verification. A
  custom sign step is a future addition.
- **Touching `~/nixos/`.** This slice is nixos only.
- **Bootstrapping the operator side.** Until at least one machine
  record has its four enrollments flipped, no install can run. That's
  by design: the repo refuses physical installs until a reviewed
  enrollment binds all exact host + device facts.

## References

- <https://github.com/nix-community/disko/blob/master/docs/disko-install.md>
- <https://nix-community.github.io/nixos-anywhere/quickstart.html>
- <https://nix-community.github.io/nixos-anywhere/howtos/no-os.html>
- <https://github.com/viperML/nh>
- <https://nixos.org/manual/nixos/stable/>