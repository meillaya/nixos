# Gate review - ulw-loop plan 01a1169d (zix x machine0 x Railway)

Reviewer: main-session self-review. A plan-reviewer child was unavailable at review
time (the provider returned an account-wide rate-limit error mid-run), so this gate
is a self-review with every claim tied to an executed command or a captured file.
That limitation is stated here rather than papered over.

## Recommendation: APPROVE

## What was asked (original intent)
1. Integrate the zix CLI into /home/mei/machine0 so coding agents can obtain any
   package/version on demand, with the lightest possible images and fast setup.
2. Build a Railway deploy template in the reference's idea-space but lighter/better.
3. Move omo-native packaging from omo-ai@beta 5.0.0-0.beta.82 to omo-ai 5.1.22.

## What is on disk and proven
- /home/mei/nixos/tools/zix 0.2.0 - `zix get NAME[@VERSION]` (repo-less runtime
  installs via the nixpkgs-multiverse store-path index; evaluating-road fallback;
  idempotence; system manifest /etc/zix/zix.json), F2 aspect-aware where/rm,
  default_target/no_pins/runtime_only. 26 offline tests; `bash tests/zix.sh` = PASS.
- /home/mei/machine0 - vendored tools/zix, pkgs/zix (0.2.0), zix.json,
  modules/packages.nix (default target), m0coding.zix.enable + /etc/zix manifest +
  PATH, omo-ai 5.1.22 (version + lockfile + hash). `nix flake check --no-build`
  exit 0; `nix build .#zix` -> zix-0.2.0; `zix get hello@2.10` from an empty cwd
  installed GNU Hello 2.10; add/rm round trip on modules/packages.nix parses.
- /home/mei/railway-nix-agent - Dockerfile (AGENT=omo|dsh|none), entrypoint
  (Caddy basic auth; agent loopback-only; proxied /healthz; tmux-persistent TTY),
  railway.json, scripts/validate.sh (15 PASS / 0 FAIL incl. five 401s with a forged
  loopback Host, /healthz 200, authenticated 200, loopback-only binding, installs
  5s/1s/2s), scripts/publish-template.sh, template/manifest.example.json, README
  with the measured table and a falsifiability section. Image 1.04 GB on disk,
  394 MiB compressed (reference 588.7 MB / 76 layers); idle RSS 37.5 MB; container
  peak 303 MiB across boot + three installs.

## Criteria coverage
36 criteria across the 12 plan goals: 36 pass, 0 fail, 0 blocked. The three
deliverable goals (G001-G003) each carry happy/edge/regression evidence; the nine
fact/constraint goals (G004-G012) are closed with the artifacts that record them
(journal, member reports, staged repo state).

## Adversarial cases exercised
- Forged loopback Host header at the proxy -> 401 (executed).
- Wrong/empty password -> 401; agent unreachable off loopback (executed).
- Old builds: hello 2.7 substitutes but crashes on modern locale data; LC_ALL=C
  fixes it (executed by a worker; boundary documented).
- Unindexed attrs: fast road refuses, zix falls back to the evaluating road and
  says so (executed).
- Provider-wide 429 killed 7 members and all 9 retrieval lanes mid-run; the
  orchestrator covered the gaps directly and no lane result was treated as
  evidence (recorded in the session journal).

## Blockers
None for the delivered scope. Explicitly deferred by the user's own answer:
live Railway deployment, machine0 VM runs, and publishing the template.

## Notes
- No git commits were made (policy: only on explicit request); both repos are
  staged, and machine0's flake was re-verified on the staged tree because nix
  reads tracked/staged content.
- One residual environmental item: /tmp/ulw-a7/npmtest is root-owned (a dead
  worker's rootful build) and needs `sudo rm -rf` to remove.
