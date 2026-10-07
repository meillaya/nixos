# RAILWAY.md - what to set on the Railway side, and the risk register

Axis A7 of ulw-research-m0-railway. Draft, 2026-10-07. Nothing here has been
deployed to a real Railway project; every number is either measured on this
workstation or quoted from a primary source, with the source named.

## 0. The Railway reality that decides the shape of this design

Railway has three configuration surfaces, and the one the reference template
would have used is the deprecated one:

| Surface | File or place | Status (read 2026-10-07) |
|---|---|---|
| Config as Code (CaC) | railway.json / railway.toml in the service repo | DEPRECATED. "Existing Config as Code files stop being read on 2026-12-01 (hard cutoff)". New services cannot opt in at all. |
| Infrastructure as Code (IaC) | .railway/railway.ts (GA), .py and .go (beta) | The replacement. Evaluated by the Railway CLI (railway config plan / apply / pull / migrate), NOT by the deploy pipeline: "Railway doesn't read .railway/ during deploys". |
| Template manifest | https://railway.com/deploy/SLUG/manifest.json (manifest_version 1.0.0) | The published template itself: services, volumes, required inputs, post-deploy healthcheck. Produced by Railway's template CI from the dashboard or API definition. |

Consequences that shape everything below:

1. A template that deploys a PREBUILT IMAGE needs no config file at all. The
   reference repo bon5co/deepseek-harness-railway contains nixos/Dockerfile,
   nixos/railway-entrypoint.sh, .github/workflows/publish.yml and NO
   railway.json / railway.toml (verified against the repo tree at HEAD,
   2026-10-07). Its healthcheck path, restart policy, volume mount and target
   port live in the template's serialized config, not in a file.
2. CaC cannot express what this image needs. CaC covers only the build and
   deploy sections: a volume mount, a domain/target port and service variables
   are NOT expressible there. They are service settings, the template manifest,
   or the IaC DSL. So "the fields we must set" is a template-manifest question;
   CaC matters only for the repo-sourced fallback.
3. Prefer the image source. The reference's own manifest records
   typical_build_seconds 0 and typical_ready_seconds 101, because Railway did no
   build at all. A repo-sourced deploy instead re-runs a Docker build (pulling
   well over 1 GB of nix store inputs from cache.nixos.org) on every deploy,
   inside Railway's build sandbox.

## 1. The fields to set, and where

railway.template.json in this draft is the manifest to produce. What each field
is for and why the value is what it is:

| Field | Value | Why |
|---|---|---|
| services[].source.image | ghcr.io/OWNER/m0-agent-railway:VERSION | Prebuilt in CI (.github/workflows/publish.yml, adapted from the reference's). No build on Railway, so no build failure on the deploy path. |
| services[].http and networking.serviceDomains."HOST:8080".port | 8080 | Railway routes one port. The image listens on the PORT variable (default 8080) and the template's target port is 8080, so the two agree; a mismatch makes the healthcheck dial a port nobody serves and the deploy fails with "service unavailable". |
| services[].needs_volume plus volume_mount_path | true, /home/agent | One volume holds sessions, config, credentials, workspace, the agent's nix profile manifest, the nix fetcher cache and the generated password. NOT /nix - see R1. |
| required_inputs[] | M0_PASSWORD, secret true, strategy generate, generate strong_password | Railway generates the value at deploy time and shows it in the dashboard. Better than the reference's "generate on first boot, print to the deploy log", because deploy logs get shared. The entrypoint still handles a blank value (it generates one onto the volume), so the image works outside a template too. |
| deploy.healthcheckPath | /healthz | Only 2xx counts. Ours is proxied to the AGENT, so a dead agent fails the deploy (section 3). |
| deploy.healthcheckTimeout | 60 (Railway default 300) | Nothing is downloaded at boot; the agent binds in seconds. Raise it if you enable M0_REPLAY with many recorded installs. |
| deploy.restartPolicyType and restartPolicyMaxRetries | ON_FAILURE / 10 | Same shape as the reference. ON_FAILURE, not ALWAYS, so a clean exit does not loop. |
| deploy.startCommand | null | The image's ENTRYPOINT owns the process; a start command would fight it. |
| deploy.drainingSeconds | 30 | A volume-mounted service gets NO overlap (Railway forbids two deployments on one volume), so a redeploy is real downtime. 30s lets the agent flush session state on SIGTERM instead of being SIGKILLed. |
| variables | M0_VARIANT (server), M0_AGENT_USER (admin), and OPTIONAL provider keys | "Nothing to fill in but your model key" - the reference's own selling point, kept: platform settings are baked into the image rather than dumped on the deploy form as blank required fields. |
| post_deploy.healthcheck | GET /healthz, expect 200 | Template CI's own post-deploy check; the reference's manifest has the same block, and its validation records checks named healthcheck and stays_up. |

railway.toml and railway.json are included only for the repo-sourced fallback,
with the deprecation date written into railway.toml's header.

## 2. Volume design, and the mistake not to make

Mount: /home/agent, one volume. What that persists:

- ~/.omo/ - sessions, agent state, agent/auth.json credentials
- ~/workspace - the agent's working tree
- ~/.nix-profile - the profile MANIFEST of everything the agent installed
- ~/.cache/nix - nix's fetcher cache, so a re-fetch after a redeploy is local
- ~/.config/nix/registry.json - the nixpkgs pin this image seeds (copy-if-missing)
- ~/.m0/password - the generated password, when the template did not supply one
- ~/.m0/install-intent.txt - attr@version lines, replayed at boot (below)

Railway volume facts that matter (docs.railway.com/reference/volumes, 2026-10-07):
one volume per service; replicas cannot use volumes; Free and Trial 0.5 GB,
Hobby 5 GB, Pro 50 GB; 3000 read and 3000 write IOPS; resizing is live on paid
plans; a redeploy that mounts the same volume has NO overlap (downtime even with
a healthcheck configured); images running as a non-root UID hit permission
errors on a volume and the documented workaround is RAILWAY_RUN_UID=0 - which
this image does not need, because it runs as root by design (a non-root UID would
require chowning the roughly 800 MB store, which costs a full layer copy).

### Why the intent file exists

/nix/store is IMAGE state; the profile manifest is VOLUME state. After a redeploy
the manifest lists store paths that no longer exist, so every package has to be
re-installed (the reference documents this and stops there). This image persists
the INTENT - hello@2.10 - and replays it in the background at boot, so the
agent's toolbox comes back as a binary-cache copy in seconds, without delaying
the healthcheck.

## 3. Healthcheck semantics

- Railway queries the healthcheck path only when a deployment starts: "Railway
  does not monitor the healthcheck endpoint after the deployment has gone live."
- The healthcheck port is the PORT variable's value; if the app listens on a
  different target port you must set PORT yourself or the check fails with
  "service unavailable".
- The prober's origin hostname is healthcheck.railway.app; an app that filters on
  Host must allow it. Our proxy does not filter on Host and rewrites Host toward
  the agent anyway.
- Default timeout 300 s, overridable per service with RAILWAY_HEALTHCHECK_TIMEOUT_SEC.

The honest difference from the reference: its /healthz is a static 200 answered by
Caddy, so the check passes as soon as the proxy is up - a dead agent behind a live
proxy still reports healthy. This design proxies /healthz to the agent's own
endpoint (M0_HEALTH_MODE=proxy, the default; static is kept for debugging only).
In both designs the supervisor takes the container down if either process dies,
so ON_FAILURE still restarts a dead agent.

## 4. RISK REGISTER

### R1 - a volume at /nix breaks the container (the number one trap)

A Railway volume mounted at a path that exists in the image SHADOWS the image's
content there. /nix holds the nix binary, the toolset profile, the store database
and every tool: mount a volume over it and the entrypoint cannot even find nix,
let alone boot the agent.

Options, in the order I would try them:

1. Do not mount /nix (this draft). Persist intent, not the store: the agent's
   installs are re-derived from the binary cache at boot (section 2). Cost: a
   redeploy re-downloads what the agent installed, seconds per package.
2. Seed the volume on first boot. Keep a copy of the store inside the image (for
   example at /nix-image), mount the volume at /nix, and on first boot copy the
   image copy into the empty volume (hardlinking where the filesystem allows).
   Costs a second copy of the store in the image layer (roughly +1.4 GB
   uncompressed) and a slow first boot; buys installs that survive redeploys with
   no replay at all.
3. Mount a volume over a subdirectory only (/nix/var/nix/profiles): does NOT
   work. The store paths those profiles point at live in the image layer, so the
   persistence is an illusion and the failure looks like "command not found".

### R2 - user namespaces and the sandbox: Railway is unprivileged

Railway containers get no extra capabilities, no --privileged, and no /dev/fuse
(a sibling axis verified this against station.railway.com while investigating
omnibin, which mounts FUSE over /nix/store and therefore cannot run on Railway at
all). For nix:

- sandbox = false and build-users-group = (single-user) are the correct settings
  and are baked into /etc/nix/nix.conf. The multi-user sandbox wants mount and
  user namespaces the platform will not give the container.
- Binary-cache substitutions - which is what "install any version" is - never
  touch the sandbox. Only a package that is cached nowhere would be built, and
  that build runs unsandboxed as root inside a single-tenant container. That is a
  real, deliberate trade: the in-container store is no longer protected from a
  malicious build. The alternative is no runtime installs at all.

### R3 - image pull time is layer SIZE and layer COUNT

Measured 2026-10-07 by reading registry manifests (compressed = what a pull
transfers):

| Image | Compressed layers | Layers |
|---|---|---|
| ghcr.io/bon5co/deepseek-harness-nixos-railway:0.1.0-rc.6 (target to beat) | 588.7 MB | 76 |
| ghcr.io/bon5co/deepseek-harness-railway:0.2.0-rc.2 (ubuntu flavor) | 363.3 MB | 10 |
| nixos/nix:2.34.8 (their base; our builder stage) | 161.5 MB | 69 |
| alpine:3.22 (our runtime base) | 3.8 MB | 1 |
| our image | see DESIGN.md, section Size | 4 |

Two engineering rules follow: never let a payload sit inside nixos/nix's 69-layer
stack when it can be on the layer we copy, and do all deletion in the builder,
because a delete AFTER a COPY does not remove the bytes from the COPY layer. A
repo-sourced deploy pays this pull on every build, which is why the image-sourced
template is the mode that makes the number matter once instead of per deploy.

### R4 - memory floor: 1 GB is the honest number

The reference measured roughly 590 MB peak during the nixpkgs channel unpack, and
Free's 0.5 GB cap killed the process with exit 137. Our own measured idle RSS and
peak during a real install are in DESIGN.md. The entrypoint's replay is
backgrounded for exactly this reason. Recommendation: 1 GB minimum, and
M0_REPLAY=0 if a deployer insists on a 0.5 GB instance for a read-only agent.
Railway's sleepApplication is about cost, not about the memory ceiling.

### R5 - one shared password is not access control

The gate is a single basic-auth password over Railway's TLS, protecting a surface
that runs arbitrary bash. That is the right gate for one operator running one
agent box - and it is not multi-user access control, and it does not protect
against someone who already has the password (the reference states the same
caveat). If the workspace will hold anything sensitive, put Cloudflare Access or
a VPN in front as well. Two cheap hardening notes: the password is stored as a
SHA-512 crypt hash in the proxy config, never the plaintext, and taking
M0_PASSWORD from the template keeps the generated value out of the deploy log.

### R6 - the agent's own installs versus redeploys

Covered in section 2. The failure mode to know: a profile manifest on the volume
whose store paths are gone makes "command not found" look like a broken image.
M0_REPLAY=1 (default) fixes it in the background; the observable is the log line
"replaying N recorded install(s)".

### R7 - dual-stack bind

Railway's edge may reach the container over IPv6. HAProxy's "bind :8080" is
IPv4-only, so the generated config binds twice (bind :8080 and bind :::8080
v6only). If a deploy ever answers on the private domain but not the public one,
this is the first thing to check.

### R8 - pin the base image by digest before publishing

NIX_IMAGE is a tag (nixos/nix:2.34.8) in this draft. The reference pinned a digest
for the right reason: "a published template is read at deploy time by strangers
who did not choose the version". Resolve it once with podman image inspect
--format with the RepoDigests index template and paste the digest into the ARG
before publishing. Measured digest for the tag used here is in DESIGN.md,
section Digests.

### R9 - what a repo-sourced deploy additionally risks

Railway would build this Dockerfile on its own builder, which needs egress to
github.com and cache.nixos.org, several GB of scratch disk for the store, and
support for the --mount=type=cache flags (BuildKit or Buildah). None of that is
verified here, and it is the reason the primary path is a prebuilt image.

### R10 - npm 11.19 silently blocks dependency install scripts (found in this image's own build)

"npm help install-scripts", run against npm 11.19.0 from nixos-26.05 nodejs_24:
"Dependency install scripts are blocked by default. Install commands silently
skip lifecycle scripts for any dependency that does not have a matching entry in
allowScripts, and end with a list of the packages whose scripts were skipped."
The first build of this image skipped four, including omo-ai's own postinstall
(node bin/senpi-patch.mjs, which prepares the senpi engine, fixes the launch
spec's permissions and installs the bun launcher shim) and esbuild's
(node install.js, which makes the platform binary usable). omo still launches
without it - the launcher prepares an unstamped engine at first run, "an
unprepared engine still runs, only without the guards" - but that is a silent
downgrade plus a first-run cost, exactly the kind of thing a container should not
ship. npm also rejects a project-scoped --allow-scripts flag outright ("npm error
code EALLOWSCRIPTS ... Add the entries to the allowScripts field in
package.json, or to .npmrc, instead"), which is how the fix was found. npm-ci.sh
therefore runs npm install-scripts approve --all (the documented workflow: it
records pinned approvals in the build tree's package.json and never touches the
shared machine0 pin) and then npm rebuild, and ASSERTS the outcome: the engine
stamp .omo-engine-prepared must exist inside the installed senpi tree, esbuild
must print its version, and npm install-scripts ls must come back empty. A future
image that loses that step fails the build instead of shipping an unprepared
engine.
