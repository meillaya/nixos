# Observation manifest (one row per observation; lead-owned)

| observation_id | source | evidence layer | observer group | independence basis | observer | observed_at | valid_at/claim_valid_at | artifact/quote anchor | contamination notes |
|---|---|---|---|---|---|---|---|---|---|
| O1 | /sys/devices/virtual/dmi/id/product_version = "ThinkPad P52" | hardware | lead | direct read | lead | 2026-10-06 | current | earlier session + app dry-run output | none |
| O2 | ~/.config/sops/age/keys.txt exists; `age-keygen -y` = age12kpavl6rfve4kgcacq0ysr4fxw5gx29fnfy2hs55av4qxj3yug6serx5yn (&workstation) | filesystem | lead | direct command | lead | 2026-10-06 | current | `age-keygen -y` output | key file not copied anywhere |
| O3 | `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops -d --extract '["github-ssh-private-key"]' secrets/github-ssh.yaml` exit 0 | filesystem | lead | direct command | lead | 2026-10-06 | current | command + exit status | private key not printed |
| O4 | `mei` has hashedPasswordFile=/var/lib/nixos-bootstrap/mei-password.hash; mutableUsers=true; no caller writes it | code | lead | nix eval + grep | lead | 2026-10-06 | current | `nix eval ...users.users.mei.hashedPasswordFile`; grep -rn 'passwd\|password' bin/host-install.sh apps/x86_64-linux/install (empty) | none |
| O5 | app flow: work tree in /root/nixos-install, --skip-fold requires --save, hosts `--yes` re-check, live-root guard | code | lead | read of apps/x86_64-linux/install | lead | 2026-10-06 | current | apps/x86_64-linux/install (session commit 6992dd2) | none |
| O6 | This laptop: nvme0n1p1 vfat /boot, nvme0n1p2 btrfs / (CachyOS); single internal NVMe | hardware | lead | lsblk | lead | 2026-10-06 | current | `lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS` | none |
| O7 | flake ISO: variant_id=installer, / tmpfs, sshd enabled, hardware-enroll oneshot exists | code | lead | nix eval of iso passthru config | lead | 2026-10-06 | current commit | earlier session eval | none |
| O8 | deployment: /home/mei/nixos/secrets/ contains github-ssh.yaml + README only; no remembrance-keys.yaml/coding-agents.yaml under /home/mei (find depth 8) | filesystem | lead | direct command | lead | 2026-10-06 | current | `ls -la secrets/`; `find /home/mei -name '*-keys.yaml'` (empty) | search bounded to /home/mei |
| O9 | lane1: bootstrap-password lifecycle pins $y$ hash, single newline, salt<=86, dir 0700/file 0600, symlinks rejected, consumer consumes to `!` | code | lane1 | read + grep | lane1 | 2026-10-06 | current | tests/bootstrap-password-lifecycle.sh:182-250 | lane1 sandbox lacked git log -S |
| O10 | lane1: no test references flake.iso / iso-images.nix / VARIANT_ID / hardware-enroll | code | lane1 | repo-wide grep | lane1 | 2026-10-06 | current | wave-1-lane-repo-tests.md | none |
| O11 | lane1: app-name lists are pinned in dendritic-apps.sh:40-51 and dendritic-config-eval.nix:13-15,146-149 | code | lane1 | read | lane1 | 2026-10-06 | current | wave-1-lane-repo-tests.md | none |
