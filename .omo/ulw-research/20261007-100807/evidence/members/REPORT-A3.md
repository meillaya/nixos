# A3 — nixpkgs-multiverse runtime mechanism + omnibin (measured 2026-10-07)

Host: Determinate Nix 3.21.5 (nix 2.34.8), experimental-features EMPTY, sandbox on, 12 cores,
/tmp tmpfs 16G, / has 274G free. Store is SHARED with other agents' builds — every store-delta
number below is an upper bound; attribution comes from each command's own `-v` log.

## VERDICT

**Yes — a container or VM can install any nixpkgs version without fetching or evaluating nixpkgs,
for everything Hydra ever built (i.e. not unfree/broken-by-policy), on x86_64-linux / aarch64-linux /
aarch64-darwin(2021+), and only for versions at or below the data pin.**

Price per request: 0 nixpkgs trees, 0 nixpkgs files evaluated, and the package's own closure from
cache.nixos.org. Measured warm: **1.11 s**, 158 MB peak RSS, 6 evaluated files (all multiverse's own).
Measured cold inside a stock `ghcr.io/nixos/nix` container: **6.77 s** (flake 4.2 MB + 20.6 MB of index
JSON + 4 substitutions); repeat **0.79 s**. The whole hello-2.10 exercise added 8 store paths / 54 MB.

What it does NOT do: nothing is ever built (pure substitution), no unfree (`vscode` throws), no version
newer than the data pin, no release branches (`fast.at "26.05"` throws by design), no `nix run` on a fake
(no drvPath — use `nix shell`/`nix build`/`nix profile install`/`mvs run`). Very old binaries can
substitute and still crash at runtime (see the 2012/2013 boundary below).

Precision on the review's wording: "the fast path skips evaluation entirely" is **false as written** —
it skips *nixpkgs* fetch and evaluation entirely, but it still evaluates the multiverse flake (3 files)
and parses ~25 MB of JSON. "Substituted straight from cache.nixos.org" is **true** (verified two ways).

## Numbers and exact commands

Prefix `M='github:fzakaria/nixpkgs-multiverse'`.

| # | command | wall | peak RSS | nixpkgs files evaluated | new store (upper bound) |
|---|---------|------|----------|------------------------|--------------------------|
| 1 | `nix run $M#mvs -- query versions hello` (COLD) | 263.95 s | 261 MB | — (builds mvs: 2130 building lines) | 3549 paths / 6.35 GB (polluted) |
| 1b | `nix run $M#mvs -- query versions ripgrep` (warm) | 2.88 s | 162 MB | — | 0 |
| 2 | `nix build -v --no-link --print-out-paths $M#fast.latest.hello.out` | **1.11 s** | 158 MB | **7 lines, 0 from github:NixOS** | 0 |
| 3 | `... $M#fast.versions.hello."2.10".out` | 1.17 s | 156 MB | 6 lines, 0 nixpkgs | 0 |
| 3b | `... $M#fast.versions.hello."2.7".out` (2012) | 8.69 s | 166 MB | 6 lines, 0 nixpkgs | 3 substitutions / 35.8 MB |
| 3c | `... $M#fast.tip.hello.out` | 1.15 s | 179 MB | 6 lines, 0 nixpkgs | 0 |
| 4 | CONTROL `... $M#latest.hello.out` (eval path, tree warm) | 0.94 s | 158 MB | **233 lines, 226 from github:NixOS** | 0 |
| 4b | CONTROL `... $M#18bd82edcc75.hello.out` (2022 rev, COLD tree) | 10.92 s | 86 MB | 127 lines, 120 nixpkgs | 261 paths / 157 MB incl 99.2 MB `-source` |
| 5 | `podman run ghcr.io/nixos/nix:latest` → `nix build ... #fast.versions.hello."2.10".out` | 6.77 s cold / 0.79 s warm | — | — | +8 paths / +54 MB |

- mvs outputs: hello — 7 versions 2.7 (2012-07-05) … 2.12.3 (current); ripgrep — 27 versions 0.2.1 … 15.2.0.
  `mvs run hello@2.10` → "hello 2.10 from the store-path index" + `Hello, world!` in 2.97 s.
  `mvs query when hello 2.10` → 711 revisions, 2 runs, one gap. `mvs solve python3@3.8 nodejs@14` →
  "1 revision · minimal". mvs runtime closure: **0.59 GB / 24 paths** (wrapper 252 MB + multiverse.db 200 MB
  + mvs 51 MB + gcc-lib 48 MB + bash 40 MB + glibc 38 MB).
- Evaluation CPU (NIX_SHOW_STATS): fast path cpuTime **0.762 s** (145,757 sets, 39,516 thunks, 1.42 M values);
  eval path `#latest.hello.outPath` cpuTime **5.366 s** (71,122 sets, 163,612 thunks, 1.09 M values).
- Cold index network cost (curl, github → this host): flake tarball 4,159,543 B / 1.80 s; outpaths-x86_64-linux.json
  13,530,399 B / 0.94 s; tip-outpaths-x86_64-linux.json 1,489,488 B / 0.27 s; outs-x86_64-linux.json
  5,543,161 B / 0.49 s → **~24.7 MB, ~3.5 s**.
- Index in the tree: `index/` 13.8 MB (versions.json 5,654,273 B; history.json 8,092,472 B; stats.json 28,341 B),
  `revisions.json` 308,639 B; full shallow clone 19 MB; compressed flake tarball 4.16 MB.

### Cache / old versions ("does cache.nixos.org serve it")
- hello 2.10 → `/nix/store/nndmy96lswhxc4xp49n950i1905qlfpy-hello-2.10`, ran `hello (GNU Hello) 2.10`;
  closure = glibc-2.33-108 (33 MB) + libidn2-2.3.2 + libunistring-0.9.10 + hello (33 MB).
  `curl -I https://cache.nixos.org/nndmy96….narinfo` → **HTTP/2 200**, last-modified 2022-02-01, `Sig: cache.nixos.org-1:…`.
- hello 2.7 (2012) → `/nix/store/cgw238mlx98ismxczzsdcqqim4h2gzjp-hello-2.7` (glibc-2.13, 31.6 MB), narinfo
  **HTTP 200**, last-modified 2015-06-03. It substitutes — but **aborts at runtime** with the host env:
  `loadlocale.c:130: _nl_intern_locale_data: Assertion …failed` (its glibc-2.13 reads a modern locale
  archive). `LC_ALL=C` and `env -i` both make it print `hello (GNU Hello) 2.7`. Same for 2.8; 2.10, 2.12.1,
  2.12.3 are fine in every environment. **Boundary ≈ 2016** (glibc-2.24-era builds).
- Local coverage of the sampled index: 730/730 sampled `(attr, version)` paths were absent from this
  100 GB store before being asked for (the index is much wider than any local store).

### Requirements (measured, not read)
- Nix with **nix-command + flakes**. Stock `ghcr.io/nixos/nix:latest` (Nix 2.35.2) has them OFF:
  `error: experimental Nix feature 'nix-command' is disabled`; with
  `--extra-experimental-features nix-command --extra-experimental-features flakes` it works.
  Determinate Nix (this host) enables them by default even with `experimental-features = ` empty.
- **No `--impure`, no `fetch-tree` feature, no root, no FUSE, no `SYS_ADMIN`.** `nix eval --pure-eval --raw
  $M#fast.latest.hello.out` → exit 0.
- Network endpoints: `github.com` / `codeload` (flake tarball + the `data-<YYYYMMDD>` release assets) and
  `cache.nixos.org` (the actual packages). Artifact integrity: `data-pins.json` narHash per file
  (`data-20261006` on this checkout), so an overwritten asset fails closed.
- Offline: warm store/mirror-cache → `nix build --offline` exit 0 for a version already fetched; a version
  not yet fetched → `error: path … is required, but there is no substituter that can build it`. No builds.
- `--option substitute false` on a not-yet-present fake → `don't know how to build these paths` +
  `there is no substituter that can build it`; the same path with substitution on copies from
  cache.nixos.org. Definitive proof the fast path is a bare path reference.

### Mechanism (verified against source, file:line in the flake)
- `multiverse.nix:741-960` — `mkFake` returns
  `{ type = "derivation"; outPath = <appendContext "/nix/store/<digest>-<name>" {path=true;}>; eval = <real drv>; drvPath = throw …; }`
  (`storePathWithContext` at `multiverse.nix:879-885`). `nix build`/`nix shell` accept a store path as an
  installable and substitute it with its whole closure; `.eval` is the real revision-exact derivation.
- `multiverse.nix:794` `readArtifact = name: builtins.fromJSON (builtins.readFile (artifactPath name))`;
  the default fetcher is `multiverse.nix:55-67`
  `fetchArtifact = {name,tag,narHash,baseUrl}: (builtins.fetchTree {type="file"; url="${baseUrl}/${tag}/${name}"; inherit narHash;}).outPath`
  — fetched during **evaluation** by a builtin, so no derivation and no nixpkgs.
- `flake.nix:4-16` — `inputs = { }` on purpose: nothing is eager; revisions come lazily via
  `builtins.fetchTree` (`multiverse.nix:44-53`) so only touched revisions are materialised.
- Honesty classes: `fast.versions`/`fast.latest` bit-exact; `fast.at`/`fast.tip` version-exact but
  build-canonical (the digest is keyed per version, taken at the newest revision that shipped it);
  releases eval-only. `fast.latest` = newest version *that has a store path* (the code notes 757 attrs
  differ from "newest that exists").
- The artifacts are **three** files per system, not one: pointing `fetchArtifact` at a directory with
  only outpaths+tip-outpaths throws `path .../outs-x86_64-linux.json does not exist`; with only outpaths it
  throws for `tip-outpaths-…`. So the "fetch exactly one small file" comment (multiverse.nix:824) is
  imprecise for terminal-step lookups — the real index cost is **20.6 MB**.

## Wiring

### (a) Container image
Verified end-to-end: stock `ghcr.io/nixos/nix:latest`, `env NIX_CONFIG="experimental-features = nix-command flakes"`,
then the tool comes in with
`nix profile install 'github:fzakaria/nixpkgs-multiverse#fast.versions.<attr>."<ver>".<output>'`
(`jq 1.6` verified via `.bin`; `nix shell '…#fast.versions.hello."2.10".out' -c hello` verified).
- Bake the index to drop GitHub from the dependency set: vendor the three JSON files (20 MB) into the
  image and import the multiverse with
  `fetchArtifact = { name, ... }: ./artifacts + "/" + name;` — verified with a local artifacts directory
  (the test failed only on the deliberately missing files). Then the network dependency is cache.nixos.org alone.
- Pin the flake to a `rev` in production: `github:fzakaria/nixpkgs-multiverse` is a floating ref (the
  data assets are hash-pinned, the flake is not).
- Do not put `mvs` in the runtime path unless you bake the binary: first `nix run .#mvs` is 264 s of Rust
  build + a 0.59 GB runtime closure (it ships a 200 MB SQLite database). Querying is 1.8–2.9 s once warm.
- **Railway cannot run omnibin** (no privileged containers, no extra caps, no `/dev/fuse`; see CLAIMS).
  The multiverse fast path has no such requirement and is the Railway-shaped mechanism.

### (b) NixOS VM (m0-coding style)
- Build-time pins: `imports = [ inputs.multiverse.nixosModules.default ]; multiverse.enable = true;
  multiverse.pins.<attr> = "<ver>";` → uses `pinOverlay` (`lib/nixpkgs.nix`), which resolves through the
  **eval** path: one nixpkgs tree per revision touched (99 MB unpacked for 2022-03; 189 MB for the 2026 tip
  in this store; project docs say ~378 MB) and `minimize = true` groups pins onto the fewest revisions.
  Good for *policy*/image content; wrong for "any version on demand" (it grows the image and re-evaluates).
- Runtime on-demand (the agent-toolbox shape): the image already has nix, so add the flake input and let
  agents run `nix shell '…#fast.…' / nix profile install …`. Cost is then per requested closure only;
  with the vendored-artifacts mirror it needs no GitHub at all.
- omnibin as a NixOS module (`services.omnibin.enable = true`) mounts the lazy store over `/nix/store` for
  the whole system, binds the real store to `/run/omnibin/real-store` first (that is what keeps the boot
  working), `mlockall`s, and appends `/omnibin/bin` last on PATH. Options `tree`, `mountStore`, `cacheDir`,
  `addToPath`. It needs `/dev/fuse` in the VM and the module calls itself "for machines you can throw
  away": the FUSE daemon becomes a dependency of every binary. `mountStore = false` serves the tree without
  touching `/nix/store`. **`nix build` does not work inside the lazy store** (not a registered store), so a
  coding VM that runs nix itself wants either `mountStore = false` or `mountStore = true` *plus* nix on the
  passthrough — while the multiverse fast path needs neither.
- Sizing for the 38.39 GB / min-80 GB image: omnibin costs +399 MB of image and *removes* the need to bake
  a toolchain, but adds FUSE+SYS_ADMIN+network; the multiverse fast path costs ~0 image weight beyond nix
  and ~25 MB of index on first use, no FUSE, and works on Railway too.

## omnibin container facts
- `podman pull docker.io/fmzakari/omnibin:latest` → 7.6 s, 418,815,862 B (**399 MiB**), digest
  `sha256:a323857968e87d1d230ed473769c72c8226c2add0adf0a5aa296632cccded88d`.
- Entrypoint `/nix/store/…-omnibin-entrypoint` mounts the lazy store at `/run/omnibin/store` with
  `--passthrough /nix/store --tree /omnibin --cache-dir /var/cache/omnibin`, waits for `/omnibin/README.md`,
  then `unshare --mount` + bind + `exec`. Without `--device /dev/fuse`: `fuse: device /dev/fuse not found`
  and `omnibin: the mount never came up; is /dev/fuse present?` (exit 1). With `--device /dev/fuse
  --cap-add SYS_ADMIN`: `omnibin: 51662 executables over 628673 store paths`.
- Contents: `omnibin` on PATH; `nix`, `nix-store`, `python3`, `curl`, `git`, `jq` resolve lazily through
  `/omnibin/bin`; `mvs`, `grail`, `rewindvm`, `wrap-buddy` are absent (those are zix/host-level).
  The image's own `/nix/store` holds 57 paths — everything else is fetched on first read.
- Timings in one persistent container: `hello` cold 0.87 s / warm 0.004 s; `hello@2.10` cold 0.73 s /
  warm 0.003 s; `python3@3.6.2` cold 9.66 s and 397 MB fetched. `omnibin which hello` 0.35 s.
- `podman run --rm` re-downloads every time: the lazy store and the NAR cache live in the container's
  writable layer. Keep one container and `exec` into it (or mount those two directories).
- Docs (caveats): nothing is local (offline = index only); commands nameable only from 2017-03-23 on
  (245,532 of 253,817 package versions on x86_64-linux); 2013-era binaries may substitute and still fail
  to run; Darwin unsupported; unofficial/`latest` tag — pin the digest.
