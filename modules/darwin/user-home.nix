{ pkgs, lib, user, ... }:
let
  # Apple Intelligence is declined per feature id under
  # com.apple.CloudSubscriptionFeatures.optIn. The id is not stable across
  # releases: this machine records 425998567, while nix-plist-manager's 26A428
  # capture puts 10334750688 behind
  # applications.systemSettings.appleIntelligenceAndSiri.appleIntelligence.
  # Writing the tool's key would leave this build opted in, so decline every
  # numeric id the domain holds when activation runs. `auto_opt_in` is the
  # other half: macOS 15.3+ opts Apple silicon Macs in by default, and an
  # upgrade can write a fresh id. The toggle reads as off only after a restart.
  disableAppleIntelligence = ''
    domain=com.apple.CloudSubscriptionFeatures.optIn
    $VERBOSE_ECHO "apple-intelligence: opting out of $domain"
    for id in $(/usr/bin/defaults read "$domain" 2>/dev/null | /usr/bin/grep -oE '[0-9]{6,}' || true); do
      $DRY_RUN_CMD /usr/bin/defaults write "$domain" "$id" -bool false
    done
    $DRY_RUN_CMD /usr/bin/defaults write "$domain" auto_opt_in -bool false
  '';
in
{
  home = {
    enableNixpkgsReleaseCheck = false;
    username = user.identity.name;
    homeDirectory = user.identity.home;
    packages = (pkgs.callPackage ./packages.nix { });
    stateVersion = "23.11";
  };

  manual.manpages.enable = false;

  home.activation.disableAppleIntelligence =
    lib.hm.dag.entryAfter [ "writeBoundary" ] disableAppleIntelligence;
}
