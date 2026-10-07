# Sources Ledger (ranked; wave-1 + wave-2)

[S1] https://github.com/fzakaria/nixpkgs-multiverse - store-path index, fast attrs, mvs CLI (source read + executed).
[S2] https://railway.com/deploy/deepseek-harness-on-nixos-just-updated-agent-with-all-of-nixpkgs--deepseek-harness-on-nixos-or-just-update - the reference template page; manifest at /manifest.json.
[S3] https://docs.railway.com/pricing/plans - plans, image caps, per-service maxima; see also /volumes/reference, /deployments/healthchecks, /deployments/serverless, /deployments/regions.
[S4] https://github.com/bon5co/deepseek-harness-railway - the reference Dockerfiles, entrypoint and verification script.
[S5] file:///home/mei/nixos/docs/research/zix-cli-critical-review-2026-10-02.md - the design input; F1-F5.
[S6] file:///home/mei/nixos/tools/zix - the CLI source and its 26 offline tests.
[S7] file:///home/mei/machine0 - the image flake; upstream at https://github.com/fdmtl/machine0-nixos.
[S8] https://docs.machine0.io - image/VM lifecycle, sizes, pricing.
[S9] https://www.npmjs.com/package/omo-ai - omo-ai metadata and the 5.1.22 tarball.
[S10] https://ghcr.io/bon5co/deepseek-harness-nixos-railway - registry manifest (561 MiB / 76 layers measured).
[S11] https://github.com/railwayapp/template-best-practices - the public template validator.
[S12] https://station.railway.com - runtime constraint threads (non-privileged containers, FUSE).
[S13] https://releases.nixos.org/nix/nix-2.24.9/nix-2.24.9-x86_64-linux.tar.xz - glibc build present; the -musl variant 404s.
[S14] https://pkgs.alpinelinux.org/package/v3.21/community/x86_64/nix - nix 2.23.3 on alpine 3.21; caddy 2.8.4, ttyd 1.7.7.
[S15] https://cache.nixos.org - narinfo availability for old builds (hello 2.10, 2016-era).
[S16] file:///home/mei/nixos/zix.json - wiring of targets, tools, checks in the nixos repo.
[S17] https://github.com/moraxyc/deepseek-harness.nix - dsh packaging (clone HEAD c19a93e).
[S18] file:///home/mei/.railway/config.json - railway CLI 5.30.4 context (login state read only).
[S19] https://docs.railway.com/guides/github-actions-runners - non-privileged containers statement.
[S20] https://github.com/fzakaria/omnibin - omnibin contents (image pulled from https://hub.docker.com/r/fmzakari/omnibin).
[S21] file:///home/mei/nixos/.omo/ulw-research/20261007-100807 - this run's journal, wave returns, claim graph and transcripts.
