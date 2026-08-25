# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# ─── How to run ───
# python3 -B scripts/hardware/discover.py root@<target-host>
# python3 -B scripts/hardware/discover.py -i ~/.ssh/id_ed25519 root@<target-host>
#
# Thin SSH wrapper around `nix run nixpkgs#nixos-facter`. The target must
# have Nix on $PATH (e.g. booted into the NixOS installer ISO).
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def ssh_gather(target: str, identity_file: str | None = None) -> bytes:
    """SSH to the target, run `nix run nixpkgs#nixos-facter`, return the
    raw JSON bytes from stdout."""
    ssh = ["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new"]
    if identity_file is not None:
        ssh += ["-i", str(identity_file)]
    nix = [
        "nix",
        "--extra-experimental-features",
        "nix-command flakes",
        "run",
        "nixpkgs#nixos-facter",
        "--",
        "-o",
        "/dev/stdout",
    ]
    proc = subprocess.run(
        ssh + [f"root@{target}", *nix],
        check=True,
        capture_output=True,
    )
    return proc.stdout


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="discover")
    parser.add_argument("target")
    parser.add_argument("-i", "--identity-file")
    parser.add_argument("-o", "--output", default="-")
    args = parser.parse_args(argv)
    data = ssh_gather(args.target, args.identity_file)
    if args.output == "-":
        sys.stdout.buffer.write(data)
    else:
        Path(args.output).write_bytes(data)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
