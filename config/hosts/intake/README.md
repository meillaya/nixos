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

Not auto-detectable (attended): the three SSH keys + two age recipients +
sops ciphertexts. They are read from `/root/enroll/trust.json`; without them the
enrollment **fails closed** and writes nothing.

After the artifact is written, copy it into this directory and commit it; the
build-time machine record follows automatically (model.nix imports the JSON).
No synthetic fixture may enroll a host.

