# Wave 2 addendum (2026-10-07) - members that resurfaced after the 429 + lead work

Provider note: after the account-wide 429, several members resumed and delivered in wave 2
(dockerfile-design, nix-container-lab, agent-packaging, skeptic, machine0-platform partials).
Their findings below are folded into the deliverable like wave-1 returns.

## A7 dockerfile-design (interim, rich)
- Railway Config-as-Code is dead: existing files stop being read 2026-12-01, new services cannot
  opt in; replacement is .railway/railway.ts and it CANNOT declare volumes/domains/variables -
  for an image-sourced template the manifest is the server-side truth. bon5co has NO railway.json.
- Reference pull weight: 588.7 MB compressed across 76 layers (ubuntu flavor 363.3 MB / 10).
  nixos/nix:2.34.8 alone 161.5 MB compressed / 557 MB disk / 69 layers; alpine:3.22 3.8 MB / 1.
- bun is the vendor-preferred omo runtime (bin/lib/bun-runtime.js); `bun bin/omo.js --version` ->
  "omo 5.1.22 (engine: senpi 2026.10.10-5)" and app-server boots under bun. bun closure 117.3 MB
  vs nodejs_24 267.0 MB -> a ~150 MB lever for this image (needs bun >= 1.4; the 25.11 nixpkgs
  bun is 1.3.3, so it would come from nixpkgs-unstable or the official installer).
- npm 11.19 blocks dependency install scripts by default (silently skipped omo-ai's senpi-patch
  in their build until approved). CHECK against machine0: the built omo-5.1.22 store path DOES
  carry the engine stamp (node_modules/@code-yeongyu/senpi/.omo-engine-prepared, content "5.1.22")
  and esbuild reports 0.28.2 -> the nix build path ran the postinstall; not affected.
- omo health surface: `omo app-server` serves the Codex app-server protocol with its own ws-token
  and an unauthenticated /healthz; the member's design proxies /healthz to the agent instead of a
  static 200 (adopted: our entrypoint proxies /healthz to the internal port, path-stripped).
- /nix must NOT be a Railway volume (it shadows the baked store); persist intent and replay in
  the background instead (noted as a future option).

## A2 nix-container-lab / A8 skeptic verdict on alpine (final)
- alpine:latest (3.24.2) `apk add nix` -> 47.2 MiB, nix 2.31.5; `nix profile add nixpkgs#hello`
  substitutes glibc hello + glibc-2.44 and runs; a sandboxed trivial build rc=0 (podman-local).
- The "musl blocks glibc store paths" premise is FALSE: store paths are self-contained; the
  official glibc nix tarball (2.24.9) also unpacks and runs on alpine.
- Reference base is scratch-style (no /etc/os-release, store carries glibc-2.42 + nix 2.35.2).
- CORRECTION to A3's fact note: "unfree (vscode) throws" did NOT reproduce -
  `nix build 'github:fzakaria/nixpkgs-multiverse#fast.latest.vscode.out'` substituted
  vscode-1.104.3 from cache.nixos.org, exit 0. Treat the earlier claim as refuted.
- Railway seccomp/userns for nix sandbox remains unverified from this workstation.
- Our shipped image uses alpine:3.21 (nix 2.23.3, validated end to end); switching to 3.22/3.24
  for nix 2.31.5 is a recorded follow-up, not a blocker (zix probes add->install).

## Lead additions in wave 2
- Fixed during validation: eval-road attr shape (was `#fast.versions.X.latest`; now
  `#versions.X."V"` versioned and `nixpkgs#X` for latest - a test now pins both).
- `/proc/net/tcp` checks corrected (host-order hex ports) in scripts/validate.sh.
- Entrypoint Caddyfile: quoted heredoc + Caddy {$VAR} substitution (the bcrypt `$` was being
  eaten by shell expansion - the template's auth would have been broken otherwise).
