# Expansion log (every lead ever seen; dedupe against this)

## Wave 1 — launch (2026-10-06 ~14:05Z)

Workers: 8 team members (repo-gap-map, anywhere-flags, password-proof, secrets-route,
prior-art, iso-autorun, skeptic, contrarian) + 9 lanes (lane1-repo-tests [done],
lane2-repo-history, lane3-anywhere-source, lane4-nixos-docs, lane5-prior-art,
lane6-transport, lane7-browse-discourse, lane8-browse-github, lane9-repo-dive).
X/social lane: skipped (brief: X signal no). Browsing lanes armed with `ultimate-browsing`.

## Lead registry

| lead_id | lead | source | status |
|---|---|---|---|
| L1 | ISO oneshot / autostart has zero test coverage; add assertions when changing iso-images.nix | lane1 | open (owner: iso-autorun member) |
| L2 | `scripts/readiness/task7/installer.py` attended-run marker is the strongest existing guard; read it end-to-end | lane1 | open (lead) |
| L3 | `tests/bootstrap-password-config-eval.nix` is orphaned (no importer); find who imported it historically | lane1 | open (owner: lane2) |
| L4 | `--extra-files` mode/ownership preservation | lane1 + Phase 0 search | open (owners: lane3, lane9, skeptic) |
| L5 | Can the flake ISO kernel mount this laptop's btrfs root? | Phase 0 | open (owner: lane6, skeptic) |
| L6 | Does a `path:` flake build include untracked files (ISO secrets bake)? | Phase 0 | open (lead) |
| L7 | Official minimal ISO sshd/root key + VARIANT_ID | Phase 0 (earlier session) | open (owner: lane4) |
| L8 | Bossearch unattended script + discourse auto-install threads | Phase 0 search | open (owners: lane5, lane7) |
| L9 | sops store inventory: what exists here, what is usable | Phase 0 | open (owner: secrets-route) |

## Wave-1 returns

- lane1-repo-tests (done): see `wave-1-lane-repo-tests.md`.

## Wave 1 — mid-wave status (journaled by lead)

Lanes completed: lane1 (repo tests), lane2 (history/RELIC), lane3 (nixos-anywhere source), lane5 (prior art),
lane6 (transport), lane7 (discourse), lane8 (GitHub threads). Lane4 (nixos docs) + lane9 (repo dive) still running.
Members completed: anywhere-flags (axis B). Running: secrets-route, prior-art, skeptic. Pending: contrarian.

MEMBER FAILURES: repo-gap-map, password-proof, iso-autorun errored at startup with NO transcript
(provider/routing failure, not a research failure). Recovery: three replacement lanes spawned with the same
briefs plus everything learned since — lane10-repo-gaps, lane11-password-proof, lane12-iso-autorun. Journal why:
the default team composition could not cover those axes, so bounded task lanes replaced them (documented
deviation from the one-team default; the team is still the primary surface for the surviving members).

Browsing-lane degradation: neither browsing lane could render or screenshot (child toolset lacks a browser and
write access). They returned first-party extracted text instead; the screenshot provenance requirement is
therefore NOT met and is recorded as a residual limitation in the synthesis gate notes.

New leads this wave: L20 (btrfs support absent on iso.antagony), L21 (fresh sops store needs no private key,
but decrypting needs &admin/&recovery which are absent), L22 (disko --mode mount repair path),
L23 (offline store-paths path), L24 (disko #1046 continue-on-failure).
