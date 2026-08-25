# entropyos CachyOS migration audit (April 24, 2026)

## Purpose

This document inventories the current user-facing software/config state on `entropyos`
and maps it into migration buckets for this repo:

- `modules/shared/*` for cross-machine config
- `modules/standalone-linux/*` for non-NixOS Linux user-space config
- host package manager / CachyOS for gaming- and hardware-sensitive packages

This is intended to guide gradual migration, not a one-shot rewrite.

## Machine summary

- Hostname: `entropyos`
- OS: CachyOS (Arch-based), `x86_64-linux`
- Session stack in use: Niri / Wayland-oriented desktop packages are present
- Nix status at audit time: not yet installed on host

## Inventory snapshot

### Package manager counts

- `pacman -Qqe`: **297** explicitly installed packages
- `pacman -Qqm`: **17** foreign/AUR packages
- Flatpak apps: **0**
- npm globals: **3**
- cargo installs: **3**
- pipx apps: **1**

### Current non-pacman user package managers

- npm globals
  - `@openai/codex`
  - `oh-my-codex`
  - `oh-my-claude-sisyphus`
- cargo installs
  - `cargo-shuttle`
  - `cargo-tauri`
  - `zeroclaw`
- pipx
  - `modal`

## Current config surface worth migrating

These paths already exist and are the most likely candidates for Home Manager ownership
or `home.file` import later:

- `~/.zshrc`
- `~/.bashrc`
- `~/.gitconfig`
- `~/.p10k.zsh`
- `~/.ssh/`
- `~/.config/fish`
- `~/.config/alacritty`
- `~/.config/ghostty`
- `~/.config/niri`
- `~/.config/waybar`
- `~/.config/wofi`
- `~/.config/mako`
- `~/.config/wlogout`
- `~/.config/qt5ct`
- `~/.config/gtk-3.0`
- `~/.config/gtk-4.0`
- `~/.config/obsidian`
- `~/.config/obs-studio`
- `~/.config/opencode`
- `~/.config/zed`
- `~/.config/spotify`

Top-level app config directories currently present under `~/.config` also include:

- `Code - OSS`, `chromium`, `google-chrome`, `BraveSoftware`
- `heroic`, `hydralauncher`, `pupgui`
- `lazygit`, `micro`, `gh`, `git`, `uv`
- `sublime-text`, `spotify`, `obsidian`, `obs-studio`, `GIMP`, `calibre`
- `noctalia`, `niri`, `waybar`, `mako`, `wlogout`, `wofi`

## Migration buckets

## 1) Shared cross-machine candidates (`modules/shared/*`)

These are strong candidates for your shared package/config layer because they are
useful across Linux and macOS or are already part of your current repo direction.

### Already in the repo or close to it

These are either already declared in the repo or obvious fits for the shared layer:

- `alacritty`
- `bash-completion`
- `btop`
- `curl`
- `direnv`
- `docker` / `docker-compose` (CLI side)
- `gh` / `github-cli`
- `git`
- `jq`
- `kubectl`
- `lazygit`
- `openssh`
- `ripgrep`
- `terraform`
- `tmux`
- `tree`
- `unrar`
- `unzip`
- `uv`
- `vim`
- `wget`
- `zoxide`

### Strong shared additions to consider next

These are installed on this machine and are good candidates for the shared layer or
shared dev-shell layer:

- `bun`
- `ccache`
- `clang20` / `lld20` / `llvm20`
- `gdb`
- `glances`
- `micro`
- `podman` (CLI only if you want it everywhere)
- `python-pipx`
- `resvg`
- `rustup` (or replace with Nix-managed Rust toolchains)
- `tectonic`
- `tokei`
- `yazi`
- `zig`

### Shared config to migrate early

Move these first because they give you the biggest cross-machine payoff:

- shell config (`bash`, `zsh`, `fish`)
- git config
- SSH config
- tmux config
- terminal config (`alacritty`, optionally `ghostty`)
- editor defaults (`vim`, maybe `zed` later)

## 2) Linux-only Home Manager candidates (`modules/standalone-linux/*`)

These fit naturally in the non-NixOS Linux user-space layer.

### Desktop/session packages

- `niri`
- `noctalia-shell`
- `waybar`
- `mako`
- `wlogout`
- `wob`
- `wofi`
- `swaybg`
- `wl-clipboard`
- `cliphist`
- `xwayland-satellite`
- `pavucontrol`
- `pamixer`
- `brightnessctl`

### Linux desktop apps that are reasonable to manage in Nix later

- `ghostty`
- `obsidian`
- `obs-studio`
- `okular`
- `qbittorrent`
- `spotify-launcher`
- `yazi`
- `zotero-bin` (if available/acceptable in nixpkgs or via overlay)
- `gimp`
- `meld`

### Linux desktop config to import later

Good import candidates from `~/.config`:

- `niri`
- `waybar`
- `mako`
- `wlogout`
- `wofi`
- `ghostty`
- `qt5ct`
- `gtk-3.0`
- `gtk-4.0`

If module support is weak, start by linking these with `home.file` before trying to
rewrite them as higher-level Nix options.

## 3) Keep on CachyOS / host package manager for now

These should remain host-managed on this machine, especially while it stays
CachyOS rather than NixOS.

### Gaming stack

Installed gaming-sensitive packages detected on the host:

- `steam`
- `heroic-games-launcher-bin`
- `lutris`
- `gamescope`
- `mangohud`
- `goverlay`
- `wine`
- `protonup-qt-bin`

### GPU / graphics / hardware stack

- `mesa`
- `lib32-mesa`
- `vulkan-radeon`
- `lib32-vulkan-radeon`
- `opencl-mesa`
- `lib32-opencl-mesa`
- `xf86-video-amdgpu`
- `amd-ucode`
- `linux-cachyos*`
- `linux-firmware`

### OS / boot / system integration

- `greetd`, `greetd-regreet`
- `grub`, `grub-btrfs-support`, `efibootmgr`, `efitools`
- `networkmanager`, `networkmanager-openvpn`, `iwd`, `dhclient`
- `cups*`, printer drivers, `splix`
- filesystem/admin packages (`btrfs-progs`, `snapper`, `mdadm`, `xfsprogs`, etc.)
- CachyOS meta/config packages (`cachyos-*`)

These are either host-sensitive, tightly integrated with Arch/CachyOS, or exactly the
kind of packages that become cleaner only after moving the whole machine to NixOS.

## 4) Keep project-local or review before globalizing

These exist, but should not automatically become global packages on every machine.

### Language/tooling managers

- npm globals
  - `@openai/codex`
  - `oh-my-codex`
  - `oh-my-claude-sisyphus`
- cargo installs
  - `cargo-shuttle`
  - `cargo-tauri`
  - `zeroclaw`
- pipx
  - `modal`

Recommendation:

- Prefer Nix packages where stable and available.
- Otherwise move them into dedicated dev shells or project-level shells.
- Avoid turning all current global tools into permanent shared global packages.

### Heavy/specialized apps to review individually

- `android-studio`
- `vagrant`
- `ollama`
- `code`
- `zed`
- `chromium`
- `brave-bin`
- `helium-browser-bin`
- `ayugram-desktop`
- `surge`

These may belong in:

- shared packages
- Linux-only packages
- host-local packages
- project shells

Decision should depend on whether you truly want them on every machine.

## 5) Foreign/AUR packages needing special handling

These are installed from outside the main repos and deserve explicit review.

- `ab-download-manager-bin`
- `android-studio`
- `dorion-bin`
- `flyctl`
- `fsearch`
- `hydra-launcher-bin`
- `lib32-gst-plugins-base-libs`
- `lib32-gstreamer`
- `pandoc-bin`
- `protonup-qt-bin`
- `python-backports-zstd`
- `riscv64-gnu-toolchain-elf-bin`
- `splix`
- `sublime-text-4`
- `surge`
- `vagrant`
- `zotero-bin`

For each one, decide one of:

1. replace with nixpkgs package
2. keep on pacman/AUR only
3. package with overlay later
4. drop

## Recommended migration order

1. **Stabilize shared shell/editor/git layer**
   - shell config
   - git config
   - SSH config
   - tmux config
   - terminal config

2. **Port Linux session config without touching gaming stack**
   - `niri`
   - `waybar`
   - `mako`
   - `wlogout`
   - `wofi`
   - `ghostty` / `alacritty`

3. **Move repeatable dev tools into Nix**
   - CLI tools from the shared bucket
   - language tooling where Nix is better than ad hoc globals

4. **Decide GUI apps case-by-case**
   - `obsidian`, `qbittorrent`, `spotify-launcher`, `gimp`, `obs-studio`, etc.

5. **Keep gaming host-managed until/unless this machine becomes NixOS**
   - Steam
   - Heroic
   - Lutris
   - gamescope
   - mangohud
   - GPU stack

## Suggested repo mapping from this audit

### `modules/shared/packages.nix`

Good place for:

- CLI/dev tools used on both macOS and Linux
- shell helpers
- git/ssh/tmux tooling
- fonts you want everywhere

### `modules/standalone-linux/packages.nix`

Good place for:

- Wayland desktop utilities
- Linux-only GUI apps
- Linux-only session helpers
- Niri/Wayland ecosystem packages

### `modules/shared/files.nix` and Home Manager program options

Good place for:

- `.gitconfig`
- `.inputrc`
- tmux config
- shell config
- `alacritty` config
- imported dotfiles from current home directory

## Appendix A: currently installed gaming-sensitive packages (all installed, not just explicit)

```text
gamescope
goverlay
heroic-games-launcher-bin
lib32-mesa
lutris
mangohud
mesa
steam
wine
```

## Appendix B: foreign/AUR packages

```text
ab-download-manager-bin
android-studio
dorion-bin
flyctl
fsearch
hydra-launcher-bin
lib32-gst-plugins-base-libs
lib32-gstreamer
pandoc-bin
protonup-qt-bin
python-backports-zstd
riscv64-gnu-toolchain-elf-bin
splix
sublime-text-4
surge
vagrant
zotero-bin
```

## Appendix C: npm/cargo/pipx global tools

```text
npm globals:
- @openai/codex
- oh-my-codex
- oh-my-claude-sisyphus

cargo installs:
- cargo-shuttle
- cargo-tauri
- zeroclaw

pipx:
- modal
```

## Appendix D: full explicit pacman package list at audit time

```text
ab-download-manager-bin
accountsservice
alacritty
alsa-firmware
alsa-plugins
alsa-utils
amd-ucode
android-studio
appmenu-gtk-module
awesome-terminal-fonts
ayugram-desktop
base
base-devel
bash-completion
bear
bemenu
bemenu-wayland
bind
bluez
bluez-hid2hci
bluez-libs
bluez-utils
brave-bin
breeze-cursors
breeze-gtk
brightnessctl
btop
btrfs-assistant
btrfs-progs
bun
cachyos-alacritty-config
cachyos-fish-config
cachyos-gaming-applications
cachyos-gaming-meta
cachyos-grub-theme
cachyos-hello
cachyos-hooks
cachyos-kernel-manager
cachyos-keyring
cachyos-micro-settings
cachyos-mirrorlist
cachyos-niri-settings
cachyos-nord-gtk-theme-git
cachyos-packageinstaller
cachyos-rate-mirrors
cachyos-settings
cachyos-v3-mirrorlist
cachyos-v4-mirrorlist
cachyos-wallpapers
cachyos-zsh-config
cantarell-fonts
capitaine-cursors
ccache
chromium
chwd
clang20
claude-code
cliphist
code
cpupower
cryptsetup
cups
cups-filters
cups-pdf
device-mapper
dhclient
diffutils
dioxus-cli
dmidecode
dmraid
dnsmasq
docker
docker-compose
dorion-bin
dosfstools
duf
e2fsprogs
efibootmgr
efitools
elixir
erlang
ethtool
ex-vi-compat
exfatprogs
f2fs-tools
fastfetch
ffmpegthumbnailer
flyctl
foomatic-db
foomatic-db-engine
foomatic-db-gutenprint-ppds
foomatic-db-nonfree
foomatic-db-nonfree-ppds
foomatic-db-ppds
fsarchiver
fsearch
gdb
ghostscript
ghostty
gimp
git
github-cli
glances
greetd
greetd-regreet
grub
grub-btrfs-support
grub-hook
gsfonts
gst-libav
gst-plugin-pipewire
gst-plugin-va
gst-plugins-bad
gst-plugins-ugly
gutenprint
haveged
hdparm
helium-browser-bin
hwdetect
hwinfo
hydra-launcher-bin
inetutils
inter-font
iptables
iverilog
iwd
jfsutils
kafka
kubectl
kvantum
kvantum-theme-nordic-git
lazygit
less
lib32-mesa
lib32-opencl-mesa
lib32-vulkan-radeon
libdvdcss
libgsf
libopenraw
libwnck3
linux-cachyos
linux-cachyos-headers
linux-cachyos-lts
linux-cachyos-lts-headers
linux-firmware
lld20
llvm20
llvm20-libs
logrotate
lsb-release
lsscsi
lvm2
mako
man-db
man-pages
mdadm
meld
mesa-utils
micro
mkinitcpio
modemmanager
mtools
nano
nano-syntax-highlighting
netctl
networkmanager
networkmanager-openvpn
nfs-utils
nilfs-utils
niri
noctalia-shell
noto-color-emoji-fontconfig
noto-fonts
noto-fonts-cjk
noto-fonts-emoji
nss-mdns
ntfs-3g
ntp
obs-studio
obsidian
octopi
okular
ollama
opencl-mesa
opencode
openssh
os-prober
otf-font-awesome
pacman-contrib
pamixer
pandoc-bin
partitionmanager
paru
pavucontrol
perl
pipewire-alsa
pipewire-pulse
pkgfile
plocate
podman
polkit-kde-agent
poppler-glib
power-profiles-daemon
protonup-qt-bin
pv
python
python-defusedxml
python-packaging
python-pip
python-pipx
qbittorrent
qt5ct
rebuild-detector
reflector
resvg
ripgrep
riscv64-gnu-toolchain-elf-bin
rsync
rtkit
rustup
s-nail
sg3_utils
smartmontools
snapper
sof-firmware
splix
spotify-launcher
sublime-text-4
sudo
surge
swaybg
swaylock-effects-git
swaylock-fancy-git
sysfsutils
system-config-printer
tailscale
tectonic
tela-circle-icon-theme-purple
terraform
texinfo
tmux
tokei
ttf-bitstream-vera
ttf-dejavu
ttf-fantasque-nerd
ttf-fira-sans
ttf-hack
ttf-liberation
ttf-meslo-nerd
ttf-opensans
ufw
unrar
unzip
upower
usb_modeswitch
usbutils
uv
vagrant
valkey
vim
vlc-plugins-all
vulkan-headers
vulkan-radeon
waybar
wget
which
wine-mono
wireless-regdb
wireplumber
wl-clipboard
wlogout
wob
woff2-font-awesome
wofi
wpa_supplicant
xdg-desktop-portal-gnome
xdg-user-dirs
xdotool
xf86-input-libinput
xf86-video-amdgpu
xfsprogs
xl2tpd
xorg-server
xorg-xdpyinfo
xorg-xinit
xorg-xinput
xorg-xkill
xorg-xrandr
xorg-xwayland
xwayland-satellite
yay
yazi
zed
zen-browser-bin
zig
zotero-bin
zoxide
```

## Notes

- `steam` is installed on the host, but not as an explicit package in `pacman -Qqe`; it
  still appears in the full installed package set and should remain host-managed.
- This audit is machine-specific and should be refreshed after the first Home Manager
  migration pass.
