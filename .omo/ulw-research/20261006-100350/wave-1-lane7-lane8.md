# Wave 1 — lane7 (discourse/reddit) + lane8 (GitHub threads) digests

Both lanes reported the SAME capability limit: the child toolset has no browser/js-eval and no
filesystem write, so neither could render pages or save screenshots under /tmp/ulw-research-shots/.
They delivered extracted text instead (Discourse .json API, GitHub API/raw). Reddit is
anonymous-curl-gated (`.json` endpoints serve the web-app shell; old.reddit/redlib gated; Wayback
was temporarily offline). Recorded as a documented degradation, not silently: browsing lanes could
not produce provenance screenshots; content still came from first-party APIs.

## Decisive content

### Unattended-install recipes (lane7, 9 discourse threads + 3 repos)
- **tfc/nixos-auto-installer** (@4a1252c): `systemd.services.install` (oneshot, multi-user.target)
  finds the biggest disk via `lsblk --json | jq`, `sfdisk --wipe=always`, mkfs, mounts /mnt,
  `nixos-install --system <toplevel> --no-root-passwd --cores 0`, then `systemctl poweroff`;
  `nix.settings.substituters = lib.mkForce []` for offline. README: "destructive ... without asking";
  only user root, literal password.
- **misuzu** (discourse 50618#2, accepted): `boot.kernelParams = [ "systemd.unit=getty.target" ]`
  + override `getty@tty1.service` with `overrideStrategy = "asDropin"`, ExecStart runs a
  writeShellApplication: partition + `nixos-install --no-channel-copy --no-root-password
  --system <toplevel>` + `reboot`. GitLab impl is UEFI-only.
- **discourse 39748#3** (accepted): extra GRUB entry with `systemd.unit=unattended-install.target`;
  service sets `SuccessAction = "reboot"`, `OnFailure = "multi-user.target"` ("so I can debug").
  Pitfall: iso-image.nix writes grub.cfg manually; patching it is "really overly complicated".
- **fricklerhandwerk** (discourse 51068#2): login hook runs `diskoScript` then
  `nixos-install --no-root-password --no-channel-copy --system <toplevel>` then reboot; the whole
  closure is baked into the image (fully offline). Related nix.dev PR #1026.
- **NiklasGollenstede/nixos-installer**: `nix run .#host -- install-system --disks=<disk>`; prompts
  only for external secrets; partlabels/ZFS/LUKS support.
- **disko #1223** (open): flake-parts module generating an `install-nixos-unattended` image.
- cloud-init `autoinstall` is Ubuntu-only (discourse 39149#3).

### First-login password pitfalls (lane7)
- discourse 47022: building a custom ISO warned "user 'root' has multiple of hashedPassword,
  password, hashedPasswordFile, initialPassword & initialHashedPassword set" — because
  profiles/installation-device.nix sets `initialHashedPassword`; fix = force it off.
  (Our flake ISO does NOT import installation-device; the official ISO DOES.)
- TLATER (community): `initialPassword` "is not much better than setting no password at all".
- Flag rename observed: `--no-root-passwd` (tfc, make-disk-image) vs `--no-root-password`
  (misuzu, fricklerhandwerk) — verify against the nixpkgs version in use.

### nixos-anywhere / disko / sops-nix thread facts (lane8, pinned SHAs)
- extra-files docs: permissions copied, ownership root; symlinks not followed; `--chown` after copy.
- `--copy-host-keys` is FLAKY: #598 (open, intermittent fresh keys) + #604 (wants a destination arg).
  => prefer `--extra-files` for host keys/secrets (matches lane3).
- nixos-anywhere #455: maintainers tell local installers to use disko-install instead.
- disko-install `--extra-files SOURCE DEST` (cp -ar after partitioning, before store copy) and
  `--disk NAME DEVICE`; open bug #1046: disko-install CONTINUES after a failing disko script.
- sops-nix: `sops.age.keyFile` + `sops.age.sshKeyPaths = []` is the clean BYO-age path;
  `age.generateKey = true` creates a random age key (NOT ssh-derived); #427/#167: missing
  ssh_host_rsa_key breaks activation unless keyPath lists are emptied; #824: upstream sops ssh→age
  conversion differs from ssh-to-age; #840: `age.keyFile` pathNotInStore assertion (workaround:
  SOPS_AGE_KEY env + keyFile=/dev/null); `sops updatekeys` is the re-encryption procedure.

## Leads
- L17: incorporate the boot-menu / getty-hijack / oneshot patterns into the ISO design
  (owner: iso-autorun member).
- L18: verify the `--no-root-passwd` name in the pinned nixpkgs and the installation-device
  `initialHashedPassword` collision on the OFFICIAL ISO (owner: password-proof member).
- L19: reddit 1dvsk9o "Automatic unattended installer thingy" remains unread (gated) —
  documented gap; not load-bearing for the design.
