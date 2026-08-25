{ den, ... }:
{
  den.aspects.qualifier-role-linux.includes = [
    den.aspects.linux-platform
    den.aspects.bootstrap-password
    den.aspects.niri
    den.aspects.noctalia
    den.aspects.linux-desktop
  ];
}
