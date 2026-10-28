# modules/aspects/ - the flat aspect tree

## OVERVIEW
Every aspect lives here, in one flat directory, next to the entity registry and
the schema. `ls modules/aspects/` is the repository's table of contents. There
are no sub-classification folders.

## STRUCTURE
```
aspects/
├── inventory.nix          # den.hosts / den.homes - identity only
├── schema.nix             # user identity, class payloads, home directory
├── nixpkgs.nix            # shared-policy
├── linux.nix, darwin.nix  # OS platform chains
├── workstation-*.nix      # personal role aggregators
├── <host>.nix             # remembrance, antagony, entropy, live, installed
├── storage-labels.nix     # NIXBOOT/NIXROOT mounts
├── x86-hardware.nix       # generic firmware, microcode, audio, power, i2c
├── distro-*.nix           # distro platform and role
├── <capability>.nix       # leaf feature aspects
└── mei.nix                # the user entity + cross-platform HM payload
```

## HOST DATA
- Entity fields: `users.<name>.identity` only.
- Aspects use `host.users.mei.identity` and `host.hostName`.
- `massive` is a `den.homes` entry with `userName` and `homeDirectory`.
- No `machine`, `boot`, `storage`, or capability record exists.

## ADD A HOST
1. Add `den.hosts.<system>.<name>.users.mei.identity` to `inventory.nix`.
2. Add `aspects/<name>.nix` with the role include and host locale/timezone.
3. If it installs to a disk, include `den.aspects.storage-labels`.
4. Update the exact name sets in `tests/dendritic-config-eval.nix`.

## ADD A FEATURE
1. Add `modules/aspects/<kebab-name>.nix`.
2. Give it a `nixos`, `darwin`, or `homeManager` payload, or `includes`.
3. Keep the implementation in `modules/nixos`, `modules/darwin`,
   `modules/shared`, `modules/linux`, `modules/standalone-linux`, or
   `modules/distro`.
4. Select it from a platform or role aggregator.

## CONVENTIONS
- Refer to peers as `den.aspects.<peer>`, never by string.
- Host-specific facts come from `host.users.mei.identity` and
  `host.hostName`.
- Storage facts come from `modules/nixos/storage-labels.nix`.
- A capability only one host uses can live inline in that host's file.

## ANTI-PATTERNS
- No `_machine-authority`, `authority.nix`, intake JSON, or `host.machine`.
- No `diskById`, UUID, or per-host storage aspect.
- No sub-folder under `aspects/`.
- No literal `"mei"` / `/home/mei` / `/Users/mei` in a feature module; read the
  entity or the `distro.liveUser` option.
- No handwritten machine record or enrollment document.
