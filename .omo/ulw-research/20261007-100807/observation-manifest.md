# Observation Manifest (key rows; wave-1)

| observation_id | source | layer | observer group | independence | observer | observed_at | valid_at | artifact | quote/anchor | contamination |
|---|---|---|---|---|---|---|---|---|---|---|
| O1 | nix build 'github:fzakaria/nixpkgs-multiverse#fast.latest.hello.out' | execution | A3 | separate member | multiverse-runtime | 2026-10-07 | 2026-10-07 | /tmp/ulw-a3/logs | store path + 1.11 s warm | shared store (upper bound) |
| O2 | alpine container: nix profile install fast.latest.ripgrep | execution | lead | independent of A3 | omo lead | 2026-10-07 | 2026-10-07 | journal + transcript | ripgrep 15.2.0 runs | shared cache |
| O3 | omo --version on built store path | execution | lead | independent of A6 | omo lead | 2026-10-07 | 2026-10-07 | /tmp/ulw-omo-build.out | "omo 5.1.22 (engine: senpi 2026.10.10-5)" | none |
| O4 | prefetch-npm-deps on new lockfile | execution | A6 | cross-check of lead | agent-packaging | 2026-10-07 | 2026-10-07 | /tmp/ulw-a6 | hash equals declared | none |
| O5 | reference manifest.json | first-party | A1+lead | platform | railway-platform | 2026-10-07 | 2026-10-07 | rail manifest fetch | typical_ready_seconds 101 | none |
| O6 | railway docs plans/pricing | docs | A1 | platform | railway-platform | 2026-10-07 | 2026-10-07 | notepad | image caps 4/100 GB | none |
| O7 | bon5co Dockerfile/entrypoint/verify | first-party | lead (lane died) | single-group | omo lead | 2026-10-07 | 2026-10-07 | gh api output | Caddy auth + loopback | none |
| O8 | machine0 flake check + build .#zix | execution | lead | independent | omo lead | 2026-10-07 | 2026-10-07 | /tmp/ulw-m0-*.out | EXIT=0 | none |
| O9 | zix get hello@2.10 repo-less | execution | lead | independent | omo lead | 2026-10-07 | 2026-10-07 | journal | "hello (GNU Hello) 2.10" | none |
