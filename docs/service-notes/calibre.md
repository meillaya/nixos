# Calibre declarative and runtime boundaries

This repo now manages the following Calibre preference files:

- `~/.config/calibre/gui.json`
- `~/.config/calibre/tweaks.json`
- `~/.config/calibre/save_to_disk.py.json`
- `~/.config/calibre/metadata_sources/global.json`
- `~/.config/calibre/conversion/page_setup.py`

## Why these files were chosen

These files express durable user preferences such as:

- save-to-disk templates
- metadata-source behavior
- conversion defaults
- UI/tweak preferences

They are comparatively stable and portable across machines.

## Synced plaintext is not declaratively managed

The following Calibre files remain outside Home Manager management:

- `global.py.json`
- `gui.py.json`
- `customize.py.json`
- plugin ZIP payloads under `~/.config/calibre/plugins/`
- caches/history/runtime data

## Why they are excluded

Those files currently contain one or more of:

- machine-specific library paths
- Windows-specific historical paths
- installation UUIDs
- search history / recently opened files
- plugin payload references that are not yet packaged declaratively

## Manual out-of-store installation

The private, ignored staging locations are:

- `secrets/calibre/global.py.json`
- `secrets/calibre/gui.py.json`
- `secrets/calibre/customize.py.json`

Home Manager does not ingest or manage these synced plaintext files. Install
them only as a manual runtime workflow outside Nix evaluation, for example:

```bash
install -d -m 0700 "$HOME/.config/calibre"
install -m 0600 secrets/calibre/{global.py.json,gui.py.json,customize.py.json} \
  "$HOME/.config/calibre/"
```

Before that manual installation, `sync-secrets` requires either `--repo-root`
or `NIXOS_REPO_ROOT`; `--repo-root` takes precedence. Omitting both fails
closed even inside a Git checkout, and there is no detected-checkout fallback.
The cloned repository URL is never logged. The sync rejects source and
destination symlinks recursively and replaces live files with an atomic
same-filesystem exchange.

This documentation records a repository contract, not a live validation.
Provider, physical-machine, native-platform, runtime-installation, and media
gates remain **NOT VERIFIED**.

Public sanitized examples remain reference material only:

- `modules/standalone-linux/templates/calibre/global.py.example.json`
- `modules/standalone-linux/templates/calibre/gui.py.example.json`
- `modules/standalone-linux/templates/calibre/customize.py.example.json`
