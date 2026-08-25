# Hardware intake

This directory is intentionally empty until an attended, descriptor-bound
Task-15 intake is reviewed and wired to the current machine architecture. No
production hardware enrollment exists here, and no synthetic fixture may enroll
a host.

`bin/nix-config-hardware-intake` accepts only a canonical JSON declaration and a
canonical RFC-6902 patch. It writes no device, reboot, activation, key, or
network state. `storage.diskById` and its expected size/sector/model/serial
hashes are attended descriptor facts; the collector never reads a device node.
