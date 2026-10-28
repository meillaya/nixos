# scripts/ - installer driver and package checks

## OVERVIEW
Stdlib-only Python and small read-only helpers. Nothing here activates a machine
by itself.

## STRUCTURE
```
scripts/
├── distro/install.py      # live ISO disk + nixos-install driver
└── check-unfree-pins.py   # unfree pin drift vs the resolved package policy
```

## COMMANDS
```bash
sudo nixos-install-tui                         # on the live ISO
sudo nixos-install-tui --test --disk /dev/vdb  # disk steps only
python3 -B scripts/check-unfree-pins.py        # non-zero on drift
```

## CONVENTIONS
- Python is stdlib only, with a PEP 723 header when run directly.
- The installer writes to `/mnt` and `/tmp/nixos-install.log`; it leaves the
  target unmounted on failure.
- `--test` stops after partitioning, filesystems, subvolumes, and mounts.
- Labels come from `NIXBOOT_LABEL` and `NIXROOT_LABEL`; the wrapper exports
  them from `modules/distro/identity.nix`.

## ANTI-PATTERNS
- Do not bind a disk to a host ID, serial, or UUID.
- Do not skip the UEFI, live-medium, read-only, or 16 GiB checks.
- Do not run `nixos-install` without `--system` and the prebuilt closure; the
  install has to stay offline.
- Do not add a shell-out where a pure validator would do.
