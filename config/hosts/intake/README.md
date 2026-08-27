# Hardware intake

Reviewed hardware enrollments live here. Each enrolled host contributes two
canonical documents emitted by the hardware-intake pipeline:

- `<host>.json` — the reviewed machine declaration (the single source of truth
  that `modules/entities/_machine-authority/model.nix` imports for the host).
- `<host>.intake.json` — the RFC-6902 patch document that transitions the
  previous record to the new one, with digest binding + reviewer + appliedAt.

`bin/nix-config-hardware-intake` accepts only a canonical JSON declaration and a
canonical RFC-6902 patch. It writes no device, reboot, activation, key, or
network state. `storage.diskById` and its expected size/sector/model/serial
hashes are attended descriptor facts; the collector never reads a device node.

## Auto-enrollment (part of the ISO install)

The per-host installer ISO (`nix build .#iso.<host>`) carries the enrollment
tooling and runs a `hardware-enroll` oneshot on the booted installer. It probes
the real target hardware and emits the candidate + intake document under
`/root/enroll/<host>.json` and `/root/enroll/<host>.intake.json`, idempotently
overwriting any prior artifact for the host.

Auto-detected: CPU vendor, UEFI/secure-boot, target-disk size/sector/model/
serial hashes, firmware/GPU/network inventory (active ethernet is selected when
several controllers are present), power daemon, audio/bluetooth/ddc presence,
and the derived capability set.

The target disk is auto-discovered on the machine (internal whole device only —
USB-attached media and external drives are excluded), preferring the disk
already bound in the base declaration when it is still present. On a machine
with several equivalent internal disks, pass `--disk` to pin the exact
whole-device basename.

Not auto-detectable (attended): the two SSH operator keys (install-authorizer +
permanent-login), the two age recipients, and the sops ciphertexts. They are
read from `/root/enroll/trust.json`; without them the enrollment **fails
closed** and writes nothing. The host's own identity key (`finalHostPublicKey`)
is **generated fresh on each install** — its private key is written to
`/root/enroll/<host>.host-key` and the public key carried into the artifact, so
the host key rotates on reinstall.

After the artifact is written, copy it into this directory and commit it; the
build-time machine record follows automatically (model.nix imports the JSON).
No synthetic fixture may enroll a host.

