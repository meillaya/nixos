# WSL via the existing standalone Linux Home Manager path

Verified against official Determinate documentation on **Friday, July 17, 2026**.

## Repo stance

- WSL is supported here as an **existing Linux install**.
- Do **not** add a dedicated `wsl` flake output, host class, or release path.
- Use the existing `standalone-linux` Home Manager output for `x86_64-linux`.
- Install **Determinate Nix** inside the WSL distro before using this repo.

This keeps WSL on the same non-NixOS Linux surface as Arch or other standalone machines, which is the intended repo model.

## Why Determinate Nix is required here

The current repo workflow assumes the standalone Linux path from `README.md`:

1. install Determinate Nix,
2. run `nix run .#home-switch`, and
3. keep using Home Manager from the same flake target.

That matches current official Determinate guidance that:

- Determinate is a supported path for **Windows Subsystem for Linux (WSL)** as well as Linux generally.
- Existing upstream Nix installs on Linux, **including WSL**, should migrate using Determinate's migration flow before switching.
- Determinate manages `/etc/nix/nix.conf`; if extra Nix config is needed, put it in `/etc/nix/nix.custom.conf` instead of editing the generated file.

## Recommended WSL bootstrap

Inside the WSL distro shell:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
nix run .#home-switch
```

Notes:

- Run the repo from the Linux side of the distro. The standalone outputs explicitly manage `mei` at `/home/mei`; shell `USER`/`HOME` values do not change that identity.
- `nix run .#home-switch` auto-selects `standalone-linux` on `x86_64-linux`.
- After first switch, continue with `home-manager switch --flake .#standalone-linux` on `x86_64-linux`.

## If the distro already has upstream Nix

Follow Determinate's migration guide first. The current official Linux guidance says most Linux installs, including WSL, can migrate by relocating `/nix/receipt.json` if needed and then rerunning the Determinate installer.

## Official references checked on Friday, July 17, 2026

- Determinate docs home: <https://docs.determinate.systems/>
- Individuals getting-started guide: <https://docs.determinate.systems/getting-started/individuals/>
- Migration guide: <https://docs.determinate.systems/guides/migrating-from-upstream-nix/>
- Determinate Nix configuration guidance: <https://docs.determinate.systems/determinate-nix/>
