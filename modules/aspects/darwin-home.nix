{
  den.aspects.darwin-home = {
    darwin = { pkgs, ... }: {
      home-manager = {
        useGlobalPkgs = true;
        backupCommand = toString (pkgs.writeShellScript "home-manager-backup-nonclobber" ''
          set -euo pipefail
          target="$1"
          base="$target.before-home-manager"
          backup="$base"
          if [ -e "$backup" ] || [ -L "$backup" ]; then
            stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%s)"
            backup="$base.$stamp"
            counter=1
            while [ -e "$backup" ] || [ -L "$backup" ]; do
              counter=$((counter + 1))
              backup="$base.$stamp.$counter"
            done
          fi
          mv "$target" "$backup"
          echo "Backed up $target to $backup" >&2
        '');
      };
    };
    provides.to-users.homeManager = import ../darwin/user-home.nix;
  };
}
