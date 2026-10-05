{ den, ... }:
{
  den.aspects.antagony-storage =
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
        den.aspects.antagony-hardware-routing
        den.aspects.enrolled-x86-storage
      ]
      else [
        den.aspects.pending-x86-workstation-hardware
        den.aspects.antagony-hardware-routing
      ];
    nixos.assertions = [
      {
        assertion = enrolled || machine.storage.profile == "none";
        message = "antagony storage must be none (pending) or single-gpt-btrfs (enrolled)";
      }
    ];
    };
}
