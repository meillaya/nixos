# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# ─── How to run ───
# Runs inside the booted installer ISO (or on a running target):
#   python3 -m hardware.auto_enroll --host remembrance \
#       --base /etc/hardware-enrollment/remembrance.json \
#       --trust /root/enroll/trust.json \
#       --out /root/enroll
#
# Auto-detects the real hardware of the machine it runs on (including the target
# disk), generates a fresh host SSH identity per install, merges the operator
# trust, sanitizes through the collector, diffs against the build-time base
# declaration, and writes the reviewed candidate + RFC-6902 intake document
# (idempotently overwriting any prior artifact for the host).
#
# The target disk is auto-discovered, preferring the disk already bound in the
# base when it is still present; pass --disk to pin an exact whole-device
# basename when several equivalent internal disks exist.
#
# Fail-closed: refuses to run without operator trust (no synthetic enrollment)
# and re-validates the applied intake before writing anything.
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from scripts.hardware.auto_enroll_core import run_enrollment


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="hardware.auto_enroll")
    parser.add_argument("--host", required=True, help="baked hostId of the target ISO")
    parser.add_argument("--base", required=True, help="path to the build-time base declaration JSON")
    parser.add_argument("--trust", required=True, help="path to operator trust fixture JSON")
    parser.add_argument("--out", default="/root/enroll", help="output directory for the enrollment artifacts")
    parser.add_argument("--reviewer", default="iso-installer", help="reviewer principal recorded in the intake")
    parser.add_argument("--disk", default=None, help="pin a target whole-device by-id basename")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = _parse_args(argv[1:])
    base_path = Path(args.base)
    trust_path = Path(args.trust)
    out_dir = Path(args.out)
    if not base_path.is_file() or not trust_path.is_file():
        print("INVALID HARDWARE INTAKE: base or trust file missing", file=sys.stderr)
        return 1
    try:
        written = run_enrollment(
            host_id=args.host,
            base_path=base_path,
            trust_path=trust_path,
            out_dir=out_dir,
            reviewer=args.reviewer,
            disk_by_id=args.disk,
        )
    except Exception as error:  # ContractError subclasses
        print(f"INVALID HARDWARE INTAKE: {error}", file=sys.stderr)
        return 1
    print(f"enrollment written: {written[0]}")
    print(f"intake written: {written[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
