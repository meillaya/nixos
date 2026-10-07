# Verification Economics (updated 2026-10-07)

| claim | risk | error cost | verification cost | chosen path | decision | outcome | residual risk |
|---|---|---|---|---|---|---|---|
| omo 5.1.22 builds and runs | high | ships a broken agent in the image | npm lockfile + prefetch hash + nix build (~6 min) | verify by execution | verify | PASS (omo --version) | none observed |
| multiverse fast path skips nixpkgs eval | high | the "lightest/fastest" claim collapses | ~10 min of container runs (member + lead) | verify by execution (two groups) | verify | PASS with wording correction | index pin horizon |
| alpine + apk nix works incl. glibc store paths | high | wrong base for the whole image | ~15 min (two runs) | verify by execution | verify | PASS (ripgrep/hello ran) | nix 2.23.3 older feature set |
| Railway template mechanics (publish flow, limits) | normal | wrong docs, invalid template | ~20 min docs sweep (A1) | verify by primary docs + CLI --help | verify | PASS (single-group; docs primary) | UI-only steps untested |
| reference image size/idle claims | normal | misleading comparison | ~10 min (manifest + imagetools) | verify (size) / defer (idle) | partial | size verified 561 MiB; idle deferred | vendor idle number stands unverified |
| machine0 38.39 GB semantics | normal | wrong slimming advice | live CLI needs user login | defer to user (flagged) | defer | ASSUMED, flagged in docs | snapshot vs closure accounting |
| auth gate + healthz on our image | high | open RCE across a public URL | ~5 min local run | verify by execution (curl matrix) | verify | see validate log | Railway healthcheck path identical |
| zix runtime install speed/RAM | high | plan-floor claim wrong | ~10 min | verify by execution (member + lead) | verify | PASS (numbers recorded) | shared-store attribution |
