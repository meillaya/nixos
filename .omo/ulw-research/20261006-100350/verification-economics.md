# Verification economics (one row per proof decision)

| claim | risk | error cost | verification cost/time | chosen path | defer/verify | outcome | residual risk |
|---|---|---|---|---|---|---|---|
| C7 extra-files modes | high | password dir/file modes wrong -> activation fails or lockout | minutes | source read + upstream test + lead tar experiment | verify | 0600/0700 preserved (VA1); setuid dropped for non-root only | 0700-dir case not exercised through a real nixos-anywhere run |
| C2 password contract | high | machine unusable | ~20 min | executed validator run with a generated yescrypt hash (VA4) + negative controls | verify | rc=0 silent; 644 and sha512 rejected | end-to-end install->reboot->login not executed (needs hardware) |
| C8 btrfs on the ISO | high | cannot read the old disk before wipe (identity loss) | ~15 min | nix evals (supportedFilesystems, kmod, kernel config) + secrets-route mount proof | verify | module present, mount works, userspace absent; one-line ISO fix | no real ISO boot |
| silent wipe semantics | high | unconfirmed wipe of the wrong machine | ~10 min | disko + nixos-anywhere source reads (two readers) | verify | confirmed; gate rule adopted | none material |
| sops/identity route | high | destroying the only age identity | ~25 min | executed decrypt + find sweeps + gen_trust runs (VA8) | verify | store absent; identity is the irreversible item; antagony needs no store | user may hold the store elsewhere (open question) |
| flake source inclusion | normal | secrets not riding the ISO, or leaking to /nix/store | ~5 min | executed scratch-flake probes (VA3) | verify | path: includes untracked; git+file does not | none |
| ISO autostart behaviour | high | wipe on a plain boot | not executed (needs a boot) | design + source (systemd conditions) + eval wall planned | defer | design only; test plan written | needs the first ISO VM test before shipping |
| reddit-class sources | low | minor coverage gap | blocked | browsing lanes (anonymous access gated) | defer | documented gap | none |
