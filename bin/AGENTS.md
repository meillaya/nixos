# bin/ - operator entry points

## OVERVIEW
One operator script remains: the Noctalia Cachix setup. The installer and the
enrollment commands moved to the live ISO / `scripts/distro/install.py`.

## STRUCTURE
```
bin/
└── setup-noctalia-cachix.sh   # writes the Nix binary-cache union (bash)
```

## COMMANDS
```bash
sudo bin/setup-noctalia-cachix.sh
```

## CONVENTIONS
- The script owns exactly one managed block (`# BEGIN/END
  setup-noctalia-cachix (managed)`) and never hand-edits the rest of the file.
- On Determinate systems the include lives in `nix.custom.conf`, never in the
  generated `nix.conf`.
- Test knobs, not test doubles: `NOCTALIA_CACHIX_TEST_MODE`,
  `NOCTALIA_CACHIX_TEST_ACTIVATION`, `NOCTALIA_CACHIX_TEST_SYSTEMCTL`,
  `NOCTALIA_CACHIX_TEST_NIX`, `NOCTALIA_CACHIX_CONF_DIR` let
  `tests/noctalia-cachix-script.sh` drive the script with mocked commands.

## ANTI-PATTERNS
- Do not add install, enroll, or key-rotation scripts here; the distro installer
  owns install and the personal hosts keep their own sops keys.
- Never run the Cachix script with a hand-written replacement for the managed
  block; a partial write is what its recovery path exists for.
