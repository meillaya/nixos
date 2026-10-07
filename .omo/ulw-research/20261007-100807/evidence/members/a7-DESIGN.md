# DESIGN.md - A7: the Railway container design, decision by decision

Axis A7 of ulw-research-m0-railway, 2026-10-07. Companion files in this
directory: Dockerfile, entrypoint.sh, m0-nixpkg.sh, m0-packages.txt, npm-ci.sh,
railway.template.json, railway.toml, railway.json, railway.ts, RAILWAY.md,
VALIDATE.sh.

## The end state this design aims at

One image, deployable as a Railway template, in which a coding agent (omo /
OmO Native 5.1.22) has a WORKING nix package manager, can obtain any package at
any version mid-session without root and without a rebuild, is reachable only
through a password gate, keeps its state across redeploys, and costs less to pull
and run than ghcr.io/bon5co/deepseek-harness-nixos-railway:0.1.0-rc.6 (measured
588.7 MB of compressed layers, 76 layers, 135 MiB idle, 1 GB plan floor).

## Layout

    internet --TLS--> Railway edge --> HAProxy 0.0.0.0:$PORT      (basic auth)
                                        |-- /healthz --> the AGENT's health
                                        '-- /*       --> agent on 127.0.0.1:3080
                                                          |
                                                          '- omo app-server (ws)
                                                             or omo TUI via ttyd

    image: alpine 3.22 (3.8 MB) + /nix (copied, post-gc) + /opt/omo (npm tree)
    volume: /home/agent  (sessions, workspace, profile manifest, intent, token)

## Decisions, each with its evidence

### D1. alpine + a COPIED nix store, not the nixos/nix image
Measured (registry manifests, 2026-10-07): nixos/nix:2.34.8 is 161.5 MB
compressed / 557 MB on disk / 69 layers; alpine:3.22 is 3.8 MB compressed /
1 layer. Nix store paths carry their own ELF interpreter
(/nix/store/...-glibc/lib/ld-linux-x86-64.so.2), so a glibc-built nix runs on a
musl userland as long as /nix is complete. The builder stage therefore does all
the work and the runtime stage receives two bulk layers.
Evidence: the probe build (/tmp/ulw-a7/proto/Dockerfile.probe2) copied /nix from
nixos/nix:2.34.8 into alpine:3.22 and ran nix from it successfully; the one thing
it exposed is D2.

### D2. nix itself comes from the base image's default profile
The first probe copied the store but could not find a nix binary, because the
toolset profile (/nix/var/nix/profiles/m0) does not contain nix - the base
image's own default profile does
(/nix/var/nix/profiles/default/bin/nix -> /nix/store/...-nix-2.34.8/bin/nix), and
it survives the gc because that profile is itself a gc root. Installing a second
nix from nixpkgs would add a whole second nix closure for no benefit. PATH
therefore has four entries in a deliberate order: the agent's own profile first
(so an agent install can shadow anything), our shims, the toolset profile, then
the base profile that carries nix.

### D3. ONE build stage, ONE copy
Every expensive step (the toolset profile, npm ci, the registry pin, the gc) runs
in the stage that owns the ORIGINAL store; the runtime stage only receives the
post-gc /nix, /opt/omo and /etc/m0. Deleting after a COPY does not remove bytes
from the COPY layer, so a "RUN rm -rf ..." in the runtime stage would be theatre.

### D4. gc'd at build time, so the deleted bytes never ship
"nix profile add" of the toolset plus the npm install took /nix to 1.4 GB; the gc
dropped it to 991 MB in the probe (204.4 MiB freed in 23 store paths, mostly the
nixpkgs source tree every flake install materialises plus the build-time node).
The draft image's post-gc size is in the Size section below.

### D5. bun, not node, at runtime
Measured closures: bun 1.4.2 = 117.3 MB, nodejs_24 (nixos-26.05) = 267.0 MB.
omo's own launcher prefers bun: "A machine that has bun runs omo on bun, whichever
package manager installed it" (omo-ai/bin/lib/bun-runtime.js @5.1.22), with
OMO_RUNTIME=node to force the other choice. Verified locally: a bun-only, empty
environment (env -i) runs "bun bin/omo.js --version" -> "omo 5.1.22 (engine:
senpi 2026.10.10-5)" AND boots the full engine - "bun bin/omo.js app-server
--listen unix:///tmp/omo-bun.sock" printed "senpi app-server listening on
unix:///tmp/omo-bun.sock" and stayed alive with the engine loaded. node is still
used at BUILD time for npm, via "nix shell" (not a profile install), so its
closure is unreferenced and the gc removes it: a bun-only image built with npm.
Residual risk: a lazily-loaded native module that only works under node. The
acceptance check is app-server boot (done) plus a real "omo --print" turn with a
provider key (the lead/deployer must supply one; not run here).

### D6. The Claude Agent SDK binary is a build ARG, not a surprise
/opt/omo/node_modules/@anthropic-ai/claude-agent-sdk-linux-x64/claude is a single
235 MB file - 45% of the 517 MB local omo tree (du breakdown: @anthropic-ai 254M,
@code-yeongyu 59M, @aws-sdk 23M, @earendil-works 17M). It exists for the Anthropic
provider. OMO_WITH_CLAUDE_SDK=0 removes it for deployments that never talk to
Anthropic; the default is 1 because silently breaking a provider is worse than a
bigger image.

### D7. HAProxy instead of Caddy
Closure sizes measured on this workstation: haproxy 3.4.4 = 63.0 MiB, ttyd 1.7.7
= 46.5 MiB, tini = 36.0 MiB (all on a nixpkgs where cacert's own closure measures
0.7 MB, so the human-readable column is trustworthy). Caddy is the reference's
choice and is a fine product; HAProxy was picked because basic auth is native
(userlist + http-request auth), WebSocket upgrades pass through in http mode, the
whole proxy is one static config file, and the health route can be a real proxy
rather than a static 200 (D8). Config generation is 40 lines of bash; the password
is stored as a SHA-512 crypt hash, never plaintext.

### D8. /healthz is proxied to the agent, not answered statically
The reference answers /healthz from the proxy itself, so a dead agent behind a
live proxy reports healthy to the deploy-time check (Railway never re-checks
after the deploy goes live, which makes the deploy-time answer the only one that
matters). M0_HEALTH_MODE=proxy (default) forwards it to the agent's own /healthz
(the omo app-server serves one: verified - /healthz -> 200 "ok" on
ws://127.0.0.1:8799, while / -> 400 "websocket upgrade required"). For the ttyd
variant, which has no unauthenticated route, the probe carries credentials and
requests "/". static is kept as a debugging escape hatch.

### D9. Three surfaces, two implemented, one honest fallback
- server (default): omo app-server, WebSocket, the protocol the omo/senpi client
  speaks ("Serve agent sessions over the Codex app-server protocol" - omo --help,
  5.1.22). It carries its own token auth (--ws-auth, default writes
  ~/.omo/agent/app-server/ws-token), so the password gate is defence in depth
  rather than the only gate.
- ttyd: the omo TUI in a browser terminal, behind the same gate.
- server-direct: no proxy at all (the app-server binds 0.0.0.0:$PORT; the
  ws-token is the only gate). Lightest, loses the shared password.
Open dependency on axis A6: which CLIENT consumes the app-server protocol
(desktop app vs CLI flag), and therefore how the token is delivered to the
operator. The image prints the token path, and M0_SHOW_WS_TOKEN=1 prints the
token itself for a deployer who wants it in the log.

### D10. Registry pinning, so the agent's own installs do not float
"nix profile install nixpkgs#foo" resolves through the flake registry, which is
the reference's floating-ref weakness. The build pins it once
(nix registry pin nixpkgs github:NixOS/nixpkgs/REV) and ships the result as
/etc/m0/registry.seed.json; the entrypoint copies it to
$HOME/.config/nix/registry.json copy-if-missing, so it survives redeploys and
never clobbers a user's own pin. /etc/m0/nixpkgs-rev carries the rev for display
and for m0-nixpkg's fallback path.

### D11. Any version, without evaluating nixpkgs
m0-nixpkg resolves attr@version through github:fzakaria/nixpkgs-multiverse's
store-path index (fast path), which substitutes the path Hydra built: a sibling
axis measured 1.11 s warm / 158 MB peak / zero nixpkgs files evaluated, 6.77 s
cold inside a stock nix container. Fallback chain: fast path -> evaluation path
(materialises nixpkgs, minutes) -> the pinned nixpkgs for an unversioned request.
The multiverse CLI (mvs) is NOT baked in: its first use costs ~264 s and a 0.59 GB
closure (also measured by the sibling axis), so it is fetched on demand and lands
in the volume's nix cache. Known gaps from that same measurement: unfree packages
have no store path in the index, versions newer than the data pin are absent, and
"nix run" does not work on a fake derivation (use #fast.latest.attr.out).

### D12. The volume carries intent, and state, but never the store
See RAILWAY.md R1/R6. /nix on a volume shadows the image's store and the
container stops booting; instead /home/agent holds everything stateful, and
~/.m0/install-intent.txt is replayed at boot in the background.

### D13. npm 11.19 blocks dependency install scripts (build correctness)
Found in this image's own build: "Dependency install scripts are blocked by
default" (npm help install-scripts, npm 11.19.0). omo-ai's postinstall - which
prepares the senpi engine and writes the .omo-engine-prepared stamp - and
esbuild's were skipped silently. npm-ci.sh approves them explicitly and then
asserts the stamp and esbuild's version, so a regression fails the build instead
of shipping an unprepared engine. See RAILWAY.md R10.

## Size budget (measured on this workstation, 2026-10-07)

| Component | Uncompressed | Compressed (pull weight) |
|---|---|---|
| alpine:3.22 | 8.1 MB (podman image size) | 3.8 MB (registry layer sum) |
| /nix after build + gc (toolset + bun 1.4.2, no node) | 972 MB, 1998 store paths | - |
| /opt/omo (omo-ai 5.1.22 tree, incl. the 235 MB claude binary) | 517 MB | - |
| whole image | 1,352,876,379 B (1.35 GB) | 434,207,832 B (434.2 MB, gzip -6 of podman save) |
| reference image | - | 588.7 MB (sum of registry layer sizes) |

The two compressed figures use different methods on purpose and are not
interchangeable: the reference number is the sum of the registry's already
gzipped layers, ours is a gzip -6 pass over the whole image because this image is
not published anywhere. Both answer "bytes a Railway pull transfers". On that
basis: **26% lighter than the reference (434 MB vs 589 MB), 4 layers instead of
76**, and with OMO_WITH_CLAUDE_SDK=0 it also drops the 235 MB Claude Agent SDK
binary that is 45% of the agent tree.

Closure sizes that drove the package list (measured with "nix path-info -S",
local nixpkgs unless stated): nodejs_24 267.0 MB, bun 1.4.2 117.3 MB, git 385.0 MB
vs gitMinimal 159.3 MB, ripgrep 54.7 MB, jq 37.1 MB, curl 65.0 MB, coreutils
48.7 MB, bashInteractive 47.2 MB, haproxy 63.0 MiB, ttyd 46.5 MiB, python3
209.4 MB (why zix is not baked into this image; it belongs to the machine0 axis),
nss-cacert 0.7 MB.

## Deliberately not done

- NixOS as the base: a full systemd userland in an unprivileged container buys
  nothing (the reference reached the same conclusion) and costs layers.
- Baking gcc/python3/playwright/docker: 50-650 MB each, and the whole point of a
  nix image is that the agent installs them on demand.
- Baking zix: it is a Python stdlib CLI over a REPOSITORY (zix.json + tracked
  targets); it belongs in machine0's NixOS image, and python3 alone is 209 MB.
  The hook is one line in m0-packages.txt if the lead decides otherwise.
- Baking the multiverse CLI: see D11.
- Pinning NIX_IMAGE by digest: see RAILWAY.md R8 (do it before publishing).

## Digests / pins recorded

- NIXPKGS_REV (built against): 2efa67fd26b6df417c33e4603185c701f260dd83
  (nixos-26.05 tip, 2026-10-07T06:11Z) - toolset, nixpkgs registry pin, npm's node
- BUN_REV: 7dd199b0e2993e37b4775ed66b1c291699608c9f (nixpkgs-unstable tip,
  2026-10-07T01:26Z) - needed because nixos-26.05 ships bun 1.3.13 and omo 5.1.22
  requires >= 1.4.0; verified bun 1.4.2 on this rev. The build asserts the floor.
- NIX_IMAGE tag used for the build: docker.io/nixos/nix:2.34.8
  digest docker.io/nixos/nix@sha256:1a711b619c8a713eff32c3f8d8781b3b4d0130cb91c0a57f67e87abfeeb90b01
  (from podman image inspect on this workstation)
- OMO_VERSION: 5.1.22 (npm latest, engine @code-yeongyu/senpi 2026.10.10-5),
  lockfile copied from machine0 pkgs/omo (already bumped to 5.1.22 in the working
  tree, npmDepsHash sha256-8XPFa9iW+F5gvpDiJ70hAFVsv/Zaf6ngDKwvqQ8IIeI=)
