# Intent vs reality

| intent_id | expected truth | observed reality | diff | violated invariant | intent source | supporting observations | status | claims |
|---|---|---|---|---|---|---|---|---|
| I1 | The install completes with no second USB and no operator machine | app requires `--skip-fold --save DIR` when the sops store is absent (today) | artifact persistence depends on external media | "zero external media" requirement | user request 2026-10-06 | O1-O3, O5 | open | C1 |
| I2 | After install `mei` can log in with a password, no manual console step | no caller stages `mei-password.hash`; validator fails on a fresh install; app never sets a password | password must be staged by the installer | "login exists" requirement | user request | O4 | open | C2 |
| I3 | The sops material present on this laptop is usable during/after install | &workstation age key + `secrets/github-ssh.yaml` exist and decrypt; `remembrance-keys.yaml` absent everywhere searched | host-key fold cannot run; sops-nix has no identity on the new host unless carried | "reuse the material that exists" | user request | O2, O3, O6 | open | C3 |
| I4 | Booting the ISO is the only human step | the flake ISO boots to a console and waits; the official ISO has no custom oneshot | autostart needs a new oneshot/gate | "everything automatic" | user request | O7 | open | C4 |
| I5 | The repo's trust boundary survives the automation | `--yes` re-checked in the destructive stage; live-root guard; four-enrollment gate | none known yet | repo invariants | repo anti-patterns | O5 | open | C5 |
| I6 | A custom installer is worth building only if it beats flake ISO + app | to be decided | unknown | user question | user request | - | open | C6 |
