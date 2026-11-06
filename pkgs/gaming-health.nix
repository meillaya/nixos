{ lib, writeShellApplication, coreutils, gnugrep, gnused }:

writeShellApplication {
  name = "gaming-health";
  runtimeInputs = [
    coreutils
    gnugrep
    gnused
  ];
  text = ''
    set -u

    echo "== Vulkan =="
    if [ -x /usr/bin/vulkaninfo ]; then
      /usr/bin/vulkaninfo --summary
    else
      echo "vulkaninfo is missing; install vulkan-tools"
    fi

    echo
    echo "== Nix driver tree =="
    readlink -f /run/opengl-driver || true
    if [ -r /run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json ]; then
      grep library_path /run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json || true
    fi
    echo "Game launchers are expected to use the host driver, not this tree."

    echo
    echo "== Niri outputs =="
    if command -v niri >/dev/null 2>&1; then
      niri msg outputs | sed -n '1,20p'
    fi

    echo
    echo "== Detected games =="
    if command -v game-trainer >/dev/null 2>&1; then
      game-trainer --list
    else
      echo "game-trainer is not on PATH"
    fi
  '';
  meta = {
    description = "Check the host graphics stack and the game trainer detector";
    mainProgram = "gaming-health";
    platforms = lib.platforms.linux;
  };
}
