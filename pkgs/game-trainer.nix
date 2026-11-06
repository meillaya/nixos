{ lib, writeShellApplication, coreutils, gnused, gnugrep, gawk, findutils, file, libnotify }:

writeShellApplication {
  name = "game-trainer";
  runtimeInputs = [
    coreutils
    gnused
    gnugrep
    gawk
    findutils
    file
    libnotify
  ];
  text = builtins.readFile ./game-trainer.sh;
  meta = {
    description = "Launch a trainer or Cheat Engine in the running Wine game prefix";
    mainProgram = "game-trainer";
    platforms = lib.platforms.linux;
  };
}
