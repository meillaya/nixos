# Claim graph (single claim store; the lead owns every node)

Status values: supported | partial | refuted | unresolved. High-risk non-code claims that clear
the Phase 4b gate are mirrored into the verified-claims digest below.

## verified-claims digest (allowlist for the synthesis)

(none yet)

## Nodes

| claim_id | statement | type | risk | scope | intent | supporting observations | contradicting | indep. groups | convergence | counter-search | primary source | deps | status | synthesis location |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C1 | The install can run with no external media once enrollment artifacts are written into the installed system (or pushed) | design | high | repo+ISO | I1 | O5 | - | lead | open | not run | repo app source | - | unresolved | - |
| C2 | A yescrypt hash staged at /var/lib/nixos-bootstrap/mei-password.hash makes `mei` loggable on first boot, satisfying the repo validator | behavior | high | repo+NixOS | I2 | O4, O17 (recovered installer script f7015a56), O18 (prior research synthesis d4f2559), O19 (gate reviews) | - | lane2 + lane1 + repo module | partial - design shipped in-tree historically; executed proof (password-proof) pending | not run | prior in-tree implementation | - | partial | - |
| C11 | The per-install password mechanism was designed, approved by a gate review, and lost in the repo consolidation rather than removed for cause | history | normal | repo | I2 | O17, O18, O19 | - | lane2 | supported (GitHub API + tree diffs, single tool) | not run | commit f7015a56 / d4f2559 | - | supported | - |
| C3 | The age key + github-ssh store on this laptop are sufficient to make sops-nix useful on the new host; remembrance-keys.yaml is not needed for login | behavior | high | repo+host | I3 | O2,O3,O6 | - | lead | open | not run | sops aspect | - | unresolved | - |
| C4 | The flake ISO can auto-run the whole install behind a safety gate (kernel cmdline / boot menu / marker) | design | high | ISO | I4 | O7 | - | lead | open | not run | iso-images.nix | - | unresolved | - |
| C5 | Automation can preserve --yes + live-root + four-enrollment gates | design | normal | repo | I5 | O5 | - | lead | open | not run | repo tests | - | unresolved | - |
| C6 | A custom installer adds enough over flake ISO + app to justify its maintenance | judgment | normal | design | I6 | - | - | lead | open | not run | - | C1,C4 | unresolved | - |
| C7 | `--extra-files` preserves file modes (0600) and writes as root:root in the target | tool behavior | high | nixos-anywhere | I1,I2 | O12 (source L876-885), O13 (upstream integration test L30-66) | none yet | lane3 + upstream test | partial - source+test agree; skeptic pass pending (L11) | not run | upstream source+test | - | partial | - |
| C8 | The flake ISO's kernel can mount this laptop's btrfs root (module + btrfs-progs present) | tool behavior | high | ISO | I3 | O6, O14 (kernel config BTRFS_FS=m), O15 (iso.antagony lacks btrfs-progs/supportedFilesystems; iso.remembrance has both) | none | lane6 + lead | PARTIAL - module exists; userspace + supportedFilesystems absent on the pending host's ISO (1-line fix) | lead eval both ISOs | kernel config + nix eval | - | partial | - |
| C10 | An ISO built from `path:.` can carry untracked local secrets; a `git+file` ISO cannot | tool behavior | high | build | I3 | O16 (lead probe: path flake shows untracked file; git+file does not) | none | lead | supported (single-source, cheap re-verify) | not run | nix eval | - | supported | - |
| C9 | The official NixOS minimal ISO runs sshd with root key login + VARIANT_ID=installer | platform | normal | upstream ISO | I4 | earlier session eval | - | lane4 | open | not run | installation-device.nix | - | unresolved | - |
