"""Static regression checks for explicit standalone Home Manager identity."""
from __future__ import annotations

import argparse
from pathlib import Path


def validate(path: Path) -> None:
    source = path.read_text(encoding="utf-8")
    prefix = source.split("}:", 1)[0]
    assert "userName," in prefix and "homeDirectory," in prefix
    assert "userName ?" not in prefix and "homeDirectory ?" not in prefix
    assert 'builtins.getEnv "USER"' not in source
    assert 'builtins.getEnv "HOME"' not in source
    assert 'builtins.getEnv "NIXOS_CONFIG_USER"' not in source
    assert 'builtins.getEnv "NIXOS_CONFIG_HOME"' not in source
    assert "username = lib.mkDefault userName;" in source
    assert "homeDirectory = lib.mkDefault homeDirectory;" in source
    assert "oh-my-codex-sidecar" not in source


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    validate(args.path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
