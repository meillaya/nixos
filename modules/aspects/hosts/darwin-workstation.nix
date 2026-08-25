{ den, ... }:
{
  # Compatibility alias. The sole Darwin entity selects entropy by name,
  # and that named-host aspect owns its complete inward-only chain.
  den.aspects.darwin-workstation.includes = [ den.aspects.workstation-role-darwin ];
}
