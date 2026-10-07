# Wave 2 — lane14 (contrarian) — completed. Reframing adopted.

## Verdicts on the premises

1. "Custom installer" is a CATEGORY ERROR: the flake ISO already is one (host config + extendModules);
   the only marginal capability is autostart, whose costs are brittle grub patching + ZERO test
   coverage. Ranking: (1) no change - one `--yes` command; (2) extend the ISO only with a
   systemd-unit gate (never a grub patch); (3) a new installer project - never.
2. "Reuse the sops store" is NOT a requirement: nothing in modules/ declares `sops.secrets`; the only
   sops wiring is `sops.age.sshKeyPaths`. gen_trust's fleet fallback lets antagony enroll with no
   store. The fold only escrows a key nothing consumes. REFRAMED as the real risk: **the
   `&workstation` age identity is the single point of no return** - it lives on the NVMe being wiped,
   and without it `home.activation.installGithubSshKey` warns/skips and the new host cannot unwrap
   `github-ssh.yaml` (&admin/&recovery are not held). Carry that identity off the disk (stage it into
   the installed root) or it is destroyed.
3. "The installer must write the password": yes, but only the CALLER is missing. `hashedPasswordFile`
   is rightmost in `overrideOrderMutable` (rightmost wins), so `initialPassword`/`hashedPassword`
   literals are silently overridden unless the module contract is removed. Ranking: restore the
   caller (historical script) > literal hashedPassword > sops-managed > first-boot wizard >
   initialPassword (overridden + plaintext).
4. "No second USB": stage into the installed root via --extra-files (recommended; fails only if the
   install fails, then the ISO work tree is still live) > regenerate after boot (rotates the host
   key) > push to GitHub (needs the identity + network) > print the host private key to console
   (unacceptable leak). `--save` becomes redundant as a REQUIREMENT; keep as an escape hatch.
5. Load-bearing: R2 (password) is the only hard requirement; R1/R4 are ergonomic; R3 reframed as
   identity preservation; R5 = no new installer.

## One-sentence recommendation (adopted into the synthesis)

The feature is ~10-40 lines of staging in `apps/x86_64-linux/install` - generate a per-install
yescrypt hash, stage it plus the `&workstation` age identity into the installed root via
`--extra-files` - not an installer project; ISO autostart is the user-requested extra and must stay
gated (trigger, not authorization) with test coverage before it ships.

## Caveats reported

- No real ISO boot executed; M4 failure analysis is design/source-based.
- Discourse citations inherited from lane7/wave-1-axis-E (unrendered).
