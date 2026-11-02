#!/usr/bin/env python3
"""Offline NixOS installer for the live ISO.

The installed system is prebuilt and carried by the ISO, so installation needs
no network and no evaluation. This script only partitions the selected disk,
creates the filesystem labels the installed system expects, runs
`nixos-install --system`, sets the user's password, and copies the flake source
to /etc/nixos for future rebuilds.

Usage:
    sudo nixos-install-tui
    sudo nixos-install-tui --disk /dev/nvme0n1 --yes
    sudo nixos-install-tui --test --disk /dev/vdb --yes --non-interactive
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import pathlib
import shutil
import subprocess
import sys
import time

TARGET = pathlib.Path("/mnt")
LOG = pathlib.Path("/tmp/nixos-install.log")
MIN_DISK_BYTES = 16 * 1024**3

INSTALLED_SYSTEM = os.environ.get("NIXOS_INSTALLED_SYSTEM", "")
FLAKE_SOURCE = os.environ.get("NIXOS_FLAKE_SOURCE", "")
BOOT_LABEL = os.environ.get("NIXBOOT_LABEL", "NIXBOOT")
ROOT_LABEL = os.environ.get("NIXROOT_LABEL", "NIXROOT")
LIVE_USER = os.environ.get("NIXOS_LIVE_USER", "mei")


def log(message: str) -> None:
    print(message, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as handle:
        handle.write(message + "\n")


def die(message: str) -> "NoReturn":
    log(f"install: {message}")
    raise SystemExit(1)


def run(argv: list[str], *, input_text: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    log("+ " + " ".join(argv))
    result = subprocess.run(
        argv,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if result.stdout:
        for line in result.stdout.splitlines():
            log("  " + line)
    if check and result.returncode != 0:
        die(f"command failed ({result.returncode}): {' '.join(argv)}")
    return result


def require_root() -> None:
    if os.geteuid() != 0:
        die("run as root (sudo nixos-install-tui)")


def require_uefi() -> None:
    if not pathlib.Path("/sys/firmware/efi").is_dir():
        die("this installer needs UEFI firmware; BIOS boot is not supported")


def block_devices() -> list[dict[str, object]]:
    result = run(
        ["lsblk", "--json", "-b", "-d", "-p", "-o", "NAME,SIZE,TYPE,TRAN,MODEL,RO"],
        check=False,
    )
    if result.returncode != 0:
        die("could not list block devices")
    data = json.loads(result.stdout or "{}")
    return list(data.get("blockdevices", []))


def parent_disk(source: str) -> str | None:
    source = source.strip()
    if not source.startswith("/dev/"):
        return None
    result = run(["lsblk", "-no", "PKNAME", source], check=False)
    name = result.stdout.strip().splitlines()
    if not name:
        return None
    parent = name[0].strip()
    return f"/dev/{parent}" if parent else source


def live_disks() -> set[str]:
    disks: set[str] = set()
    for mount in ("/iso", "/nix/.ro-store", "/nix/store"):
        result = run(["findmnt", "-no", "SOURCE", mount], check=False)
        if result.returncode != 0 or not result.stdout.strip():
            continue
        source = result.stdout.strip()
        if source.startswith("/dev/"):
            disk = parent_disk(source)
            if disk:
                disks.add(disk)
    return disks


def read_only(disk: str) -> bool:
    name = pathlib.Path(disk).name
    path = pathlib.Path("/sys/block") / name / "ro"
    try:
        return path.read_text(encoding="utf-8").strip() == "1"
    except OSError:
        return False


def eligible_disks() -> list[dict[str, object]]:
    live = live_disks()
    result = []
    for device in block_devices():
        name = str(device.get("name", ""))
        kind = str(device.get("type", ""))
        if kind != "disk" or not name.startswith("/dev/"):
            continue
        if name in live or read_only(name):
            continue
        size = int(device.get("size") or 0)
        if size < MIN_DISK_BYTES:
            continue
        result.append(device)
    return result


def human(size: object) -> str:
    value = float(size or 0)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if value < 1024 or unit == "TiB":
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{value:.1f} TiB"


def choose_disk(explicit: str | None, assume_yes: bool, non_interactive: bool) -> str:
    disks = eligible_disks()
    if explicit:
        if not any(str(device["name"]) == explicit for device in disks):
            die(f"{explicit} is not an eligible whole disk (UEFI, >=16 GiB, not the live medium)")
        return explicit
    if non_interactive:
        die("--non-interactive needs --disk")
    if not disks:
        die("no eligible disk found; pass --disk explicitly")
    print("\nEligible disks:")
    for index, device in enumerate(disks, start=1):
        print(
            f"  {index}. {device['name']}  {human(device.get('size'))}  "
            f"{device.get('model') or 'unknown model'}  {device.get('tran') or ''}"
        )
    choice = input("\nDisk number: ").strip()
    try:
        selected = disks[int(choice) - 1]
    except (ValueError, IndexError):
        die("invalid disk selection")
    disk = str(selected["name"])
    print(
        f"\nTarget: {disk}\n"
        f"  size:  {human(selected.get('size'))}\n"
        f"  model: {selected.get('model') or 'unknown'}\n"
        "Everything on this disk will be erased."
    )
    if not assume_yes and input('Type "YES" to continue: ') != "YES":
        die("cancelled")
    return disk


def partition_name(disk: str, number: int) -> str:
    return f"{disk}p{number}" if disk[-1:].isdigit() else f"{disk}{number}"


def partition(disk: str) -> tuple[str, str]:
    run(["wipefs", "-a", "-f", disk])
    layout = (
        "label: gpt\n"
        f'size=1GiB, type=EF00, name="{BOOT_LABEL}"\n'
        f'type=8300, name="{ROOT_LABEL}"\n'
    )
    run(["sfdisk", "--wipe", "always", "--wipe-partitions", "always", disk], input_text=layout)
    run(["udevadm", "settle"], check=False)
    run(["partx", "-u", disk], check=False)
    time.sleep(1)
    boot = partition_name(disk, 1)
    root = partition_name(disk, 2)
    if not pathlib.Path(boot).exists() or not pathlib.Path(root).exists():
        die(f"partitioning {disk} did not create the expected partitions")
    return boot, root


def mount_layout(root: str, boot: str) -> None:
    TARGET.mkdir(parents=True, exist_ok=True)
    run(["mkfs.fat", "-F", "32", "-n", BOOT_LABEL, boot])
    run(["mkfs.btrfs", "-f", "-L", ROOT_LABEL, root])

    run(["mount", root, str(TARGET)])
    for subvolume in ("@root", "@home", "@nix", "@log"):
        run(["btrfs", "subvolume", "create", str(TARGET / subvolume)])
    run(["umount", str(TARGET)])

    run(["mount", "-o", "subvol=@root,compress=zstd:3,noatime", root, str(TARGET)])
    for subvolume, mountpoint in (
        ("@home", "home"),
        ("@nix", "nix"),
        ("@log", "var/log"),
    ):
        path = TARGET / mountpoint
        path.mkdir(parents=True, exist_ok=True)
        run(["mount", "-o", f"subvol={subvolume},compress=zstd:3,noatime", root, str(path)])
    (TARGET / "boot").mkdir(parents=True, exist_ok=True)
    run(["mount", "-o", "umask=0077", boot, str(TARGET / "boot")])


def unmount() -> None:
    result = run(["umount", "-R", str(TARGET)], check=False)
    if result.returncode != 0:
        log(f"install: warning: could not unmount {TARGET} cleanly")


def show_layout() -> None:
    run(["lsblk", "-o", "NAME,SIZE,LABEL,PARTLABEL,FSTYPE,MOUNTPOINTS"])
    run(["btrfs", "subvolume", "list", str(TARGET)])


def install(password: str) -> None:
    if not INSTALLED_SYSTEM:
        die("NIXOS_INSTALLED_SYSTEM is not set")
    if not FLAKE_SOURCE:
        die("NIXOS_FLAKE_SOURCE is not set")

    (TARGET / "etc/nixos").mkdir(parents=True, exist_ok=True)
    run(
        [
            "nixos-install",
            "--root",
            str(TARGET),
            "--system",
            INSTALLED_SYSTEM,
            "--no-root-passwd",
            "--no-channel-copy",
        ]
    )

    run(
        ["nixos-enter", "--root", str(TARGET), "-c", "chpasswd"],
        input_text=f"{LIVE_USER}:{password}\n",
    )

    source = pathlib.Path(FLAKE_SOURCE)
    if not source.is_dir():
        die(f"flake source is not a directory: {source}")
    shutil.copytree(source, TARGET / "etc/nixos", dirs_exist_ok=True, symlinks=True)
    run(["chmod", "-R", "u+w", str(TARGET / "etc/nixos")])

    log_path = TARGET / "var/log/nixos-install.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(LOG, log_path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Install the prebuilt NixOS system on a disk.")
    parser.add_argument("--disk", help="whole-disk device, for example /dev/nvme0n1")
    parser.add_argument("--yes", action="store_true", help="skip the typed confirmation")
    parser.add_argument("--non-interactive", action="store_true", help="never prompt")
    parser.add_argument("--test", action="store_true", help="partition and mount, then stop")
    args = parser.parse_args()

    LOG.write_text("", encoding="utf-8")
    os.chmod(LOG, 0o600)
    require_root()
    require_uefi()

    disk = choose_disk(args.disk, args.yes, args.non_interactive)
    if not args.yes and not args.non_interactive and input(f'Type "YES" to erase {disk}: ') != "YES":
        die("cancelled")

    log(f"install: target {disk}")
    mounted = False
    try:
        boot, root = partition(disk)
        mount_layout(root, boot)
        mounted = True
        show_layout()

        if args.test:
            log("install: test mode complete; no system was installed")
            return 0

        password = os.environ.get("NIXOS_PASSWORD")
        if password is None:
            if args.non_interactive:
                die("set NIXOS_PASSWORD for --non-interactive")
            password = getpass.getpass(f"Password for {LIVE_USER}: ")
            if password != getpass.getpass("Repeat password: "):
                die("passwords do not match")
        if not password:
            die("password must not be empty")

        install(password)
        log(f"install: complete; remove the ISO and reboot into {LIVE_USER}")
        return 0
    finally:
        if mounted:
            unmount()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
