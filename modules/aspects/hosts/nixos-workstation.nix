{ den, ... }:
{
  den.aspects.x86_64-linux.includes = [ den.aspects.remembrance ];

  # Compatibility alias for external references; concrete hosts select a
  # literal named-host aspect instead of this generic aggregate.
  den.aspects.nixos-workstation.includes = [ den.aspects.workstation-role-linux ];
}
