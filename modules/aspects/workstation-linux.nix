{ den, ... }:
{
  den.aspects.workstation-role-linux.includes = [
    den.aspects.linux-platform
    den.aspects.niri
    den.aspects.noctalia
    den.aspects.linux-desktop
  ];
}
