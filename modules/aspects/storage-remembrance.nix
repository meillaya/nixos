{ den, ... }:
{
  den.aspects.remembrance-storage =
    { host, ... }:
    let
      machine = host.machine;
      enrolled = machine.storage.profile == "single-gpt-btrfs";
    in
    {
    includes =
      if enrolled
      then [
        den.aspects.enrolled-x86-workstation-hardware
        den.aspects.remembrance-hardware-routing
        den.aspects.enrolled-x86-storage
      ]
      else [
        den.aspects.pending-x86-workstation-hardware
        den.aspects.remembrance-hardware-routing
      ];
    nixos.assertions = [
      {
        assertion = enrolled || machine.storage.profile == "none";
        message = "remembrance storage must be none (pending) or single-gpt-btrfs (enrolled)";
      }
    ];
    };
}
