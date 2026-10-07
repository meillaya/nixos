# Cause Disappearance (updated 2026-10-07)

| cause id | expected truth | previous observation | last_seen | disconfirming observation | replacement cause | status | violation gone? |
|---|---|---|---|---|---|---|---|
| CD1 | `zix get` is idempotent (zix style) | second run installed a duplicate (`hello-1` entry) - nix profile JSON `elements` is a name-keyed dict without a `name` field; the matcher missed | 2026-10-07 (first real run) | after the fix, second run prints "already installed" and no new entry appears | name-keyed dict handling + NAME-\d suffix match | closed | yes |
| CD2 | any real zix subcommand requires a zix.json | `zix get` died with "no zix.json found" in an empty cwd | 2026-10-07 (source read + probe) | after REPO_OPTIONAL + system manifest, `zix get hello@2.10` ran in /tmp with no repo | repo-optional commands + /etc/zix manifest | closed | yes |
| CD3 | alpine's nix supports `nix profile add` | `error: 'add' is not a recognised command` from nix 2.23.3 | 2026-10-07 | after the add->install probe, installs succeed on the same container | `_profile_verb` probe + plain-list fallback | closed | yes |
| CD4 | the review's "fast path skips evaluation entirely" | A3 counted 233 evaluating-file lines on the eval road vs 6-7 (3 flake files + JSON parse) on the fast road | 2026-10-07 | the same measurement shows the fast road still evaluates 3 files | wording corrected in the review update | closed (wording) | yes |
| CD5 | tests/zix.sh smoke: "usable without a repository (help and version only)" | the script's step 1 asserts that; `get` now breaks the exclusivity | 2026-10-07 | tests/zix.sh extended to include `get --help`; step 3 unchanged; suite PASS | get added to the cmd loop | closed | yes |
