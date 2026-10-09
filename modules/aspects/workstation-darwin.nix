{ den, ... }:
{
  den.aspects.workstation-role-darwin.includes = [
    den.aspects.darwin-platform
    den.aspects.darwin-dock
  ];
}
