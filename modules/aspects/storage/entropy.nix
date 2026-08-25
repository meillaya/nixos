{ den, ... }:
{
  den.aspects.entropy-storage =
    { host, ... }:
    let
      machine = host.machine;
    in
    assert machine.storage.profile == "none";
    {
    includes = [ den.aspects.apple-silicon-hardware ];
    darwin.assertions = [
      {
        assertion = machine.storage.profile == "none";
        message = "aarch64-darwin storage remains externally managed";
      }
    ];
    };
}
