# ULW-Research Brief: zero-touch NixOS install for the ThinkPad (antagony)

Session: `.omo/ulw-research/20261006-100350` · created 2026-10-06 · lead: this session

## Core question

What is the minimal, robust design that turns today's multi-step ThinkPad install into
"boot the ISO, and the install happens", meeting these stated requirements:

1. **No second USB** — nothing outside the machine + the install medium may be needed.
2. **A login password must exist after install** (today the repo's bootstrap-password
   contract fails on a fresh install: no `mei-password.hash` is ever staged, and the
   user cannot log in at the console).
3. **The sops material that already exists on this laptop must be reused** (the user has
   no access to the "first" sops store; they believe one exists here).
4. **Minimal manual steps on either the flake ISO or the official NixOS ISO.**
5. Verdict on the user's proposal: **"maybe we need to build a custom installer?"** —
   what exactly would a custom installer add over the current flake ISO + app?

## Analysis (Phase 0)

- Codebase relevant: yes (this repo: `apps/x86_64-linux/install`, `bin/host-install.sh`,
  `scripts/hardware/*`, `modules/nixos/bootstrap-password.nix`,
  `modules/aspects/features/{sops,bootstrap-password}.nix`, `modules/flake/iso-images.nix`).
- External: yes (nixos-anywhere, disko-install, nixos-install, sops-nix, clan,
  nixos-facter, nixos-generators, NixOS manual, discourse/gists on unattended installs).
- Browsing: yes (discourse.nixos.org and GitHub threads are JS-rendered; screenshots as
  provenance for the top sources).
- Verification likely: yes (extra-files mode/ownership; yescrypt hash accepted by the
  repo's validator; btrfs mount from the ISO kernel; ISO oneshot ordering/autostart;
  sops decryptability of the material present on this laptop).
- X/social signal: no (skip the X lane; recorded in expansion-log).
- Scale: 6 axes, 17 workers (8 members + 9 lanes) per the Multi-faceted floor.
- Precision demand: high — a wrong design claim costs a wiped disk or a locked-out
  machine; every mechanism claim must be executed or source-pinned.
- Lifecycle: research team now; on convergence a REFINEMENT team (`ultrabrain` +
  `architect`) attacks the synthesis before materials are written.

### Phase-0 facts already in hand (lead's scoping, to be re-verified by lanes)

- This laptop: ThinkPad P52 (`antagony`), CachyOS on btrfs `nvme0n1p2`, `/boot` vfat
  `nvme0n1p1`, ~30 GiB RAM, UEFI, single internal NVMe (INTEL SSDPEKNW512G8H).
- `~/.config/sops/age/keys.txt` exists and is the `&workstation` identity
  `age12kpavl6rfve4kgcacq0ysr4fxw5gx29fnfy2hs55av4qxj3yug6serx5yn`.
- `secrets/github-ssh.yaml` is a sops store present here and it DOES decrypt with that
  key (`sops -d --extract '["github-ssh-private-key"]'` → exit 0).
- `secrets/remembrance-keys.yaml` does not exist anywhere under `/home/mei` (searched to
  depth 8); neither does `secrets/coding-agents.yaml` (referenced by the enrollment
  record's ciphertexts).
- The repo's install app (`apps/x86_64-linux/install`) already: auto-detects the P52,
  probes hardware, writes the enrollment into a RAM work tree, folds the host key when a
  sops store + age key are present, else requires `--skip-fold --save DIR`; then runs
  `bin/host-install.sh --install-only` (build gate + nixos-anywhere to root@127.0.0.1).
- The flake ISO already boots a oneshot (`hardware-enroll`) and now sets
  `VARIANT_ID=installer`; `/` is tmpfs; sshd runs; root + mei accept the fleet key
  `...tbWtb5` (not present on this laptop as a private key).

## Axes and owners (members)

| Axis | Owner (member) | What a complete answer contains |
|---|---|---|
| A. Repo gap map | `repo-gap-map` (deep-low) | file:line map of the current install flow; the exact gaps for a zero-touch install (password, secrets channel, artifact persistence, autostart); what each gap costs to close |
| B. Remote-install tool surface | `anywhere-flags` (deep-low) | nixos-anywhere/nixos-install/disko-install flag semantics that enable local, unattended installs (--extra-files, --chown, --phases, --no-root-passwd, --generate-hardware-config, local mode), version-pinned |
| C. Password provisioning | `password-proof` (unspecified-high) | NixOS password options + how to generate and stage a hash at install time; the repo's sentinel/consume contract; executed proof that a generated yescrypt hash passes the repo validator |
| D. Secrets route | `secrets-route` (deep-low) | inventory of secret material on this laptop; every mechanism to carry it into the install (ISO bake, old-disk discovery, extra-files, fresh-age-identity); what breaks without remembrance-keys.yaml |
| E. Prior art | `prior-art` (deep-low) | clan / nixos-facter / disko-install / nixos-generators / unattended-ISO threads / Bossearch gist — what to crib, what to avoid |
| F. ISO autostart | `iso-autorun` (unspecified-high) | how the booted ISO can run the install by itself (systemd oneshot, getty, kernel-cmdline gate, safety), on the flake ISO and what remains possible on the official ISO |
| Attack 1 | `skeptic` (ultrabrain) | attacks every claim, evidence quality, source independence, and the synthesis structure |
| Attack 2 | `contrarian` (ultrabrain) | attacks the framing: "custom installer" vs simpler paths, the premise that the store must be preserved, the premise that password staging must live in the installer |

## Lanes (wave 1, unique angles)

- `explore` #1 — the repo's *tests and readiness harness* constraining install changes
  (`tests/bootstrap-password-*`, `tests/readiness/task7`, dendritic checks): what a
  change must not break.
- `explore` #2 — repo *history archaeology*: the deleted installer scripts
  (`bin/nixos-anywhere-bootstrap-password.sh` era), prior `.omo/ulw-research` runs and
  their evidence, and `git log -S` traces for how passwords/extra-files were staged.
- `librarian` #1 — nixos-anywhere docs + source: --extra-files/--chown/--phases/local
  install/--no-root-passwd/disko behavior, pinned.
- `librarian` #2 — NixOS manual/options + sops-nix: password options, mutableUsers,
  nixos-install flags, sops age key discovery, ssh-to-age, re-encryption.
- `librarian` #3 — prior art sweep (clan, nixos-facter, nixos-generators, unattended
  install threads/gists, kexec installers).
- `librarian` #4 — recovery/transport mechanics: mounting btrfs from an installer,
  nixos-enter/chroot, carrying files into the target, creating a replacement
  remembrance-keys.yaml.
- `browsing` #1 (armed `ultimate-browsing`) — JS-rendered discourse.nixos.org threads +
  r/NixOS on unattended/zero-touch installs, screenshots as provenance.
- `browsing` #2 (armed `ultimate-browsing`) — GitHub issue/PR threads (nixos-anywhere,
  disko, sops-nix) with rendering needed; screenshots.
- repo-dive — shallow-clone nixos-anywhere + disko (+ sops-nix) at pinned HEADs and read
  the install/extra-files implementation.

## Expected truths seeding intent-diff.md

- `I1` The install can finish with no USB and no operator machine. (Intent: user.)
- `I2` After the install `mei` can log in with a password known to the user, with no
  manual console step. (Intent: user.)
- `I3` The sops material present on this laptop is usable by/during the install.
  (Intent: user.)
- `I4` Booting the flake ISO (or the official ISO) is the only human step. (Intent: user.)
- `I5` The repo's reviewed-enrollment trust boundary (four-enrollment gate, --yes,
  live-root guard) survives the automation. (Intent: repo invariants.)
- `I6` A "custom installer" is only worth building if it beats the flake ISO + app.
  (Intent: user question.)

## Deliverable (recorded per deliverable-phase.md)

```
lane: no-format
state: none
formats: post (the chat answer), md (SYNTHESIS.md in the session dir) (answered_by: default)
destination: this chat session (answered_by: request)
audience: the operator (user), standard (answered_by: default)
template: repo service-note register (answered_by: default)
format description: none
```

No interview: lane `no-format` derives from the destination (a chat answer). A late
preference is folded in until the assembly lane starts.

## Team roster

8 members as tabled above; debate members are `skeptic` + `contrarian`.

## Journaling rules

Every finding, source, quote, number and lead lands in this directory the instant it
arrives (wave files + sources-ledger + observation-manifest + claim-graph). Workers
never write files; they report as message text with `## EXPAND` and `## CLAIMS` tails.
