{ den, ... }:
{
  den.aspects.distro-role.includes = [
    den.aspects.distro-platform
    den.aspects.niri
    den.aspects.noctalia
    den.aspects.linux-desktop
  ];
}
