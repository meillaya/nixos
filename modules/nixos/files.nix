{ homeDirectory }:
{
  ".config/niri/config.kdl".text = builtins.readFile ../linux/config/niri/config.kdl;
  ".config/noctalia/config.toml".text = builtins.replaceStrings
    [ "@HOME@" ]
    [ homeDirectory ]
    (builtins.readFile ../standalone-linux/config/noctalia/config.toml);
}
