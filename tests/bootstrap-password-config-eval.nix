{ config }:
{
  hashFile = config.users.users.mei.hashedPasswordFile;
  mutableUsers = config.users.mutableUsers;
  sysusers = config.systemd.sysusers.enable;
  userborn = config.services.userborn.enable;
  userGroups = config.users.users.mei.extraGroups;
  authorizedKeys = config.users.users.mei.openssh.authorizedKeys.keys;
  hasValidator = config.system.activationScripts ? bootstrapPasswordHash;
  hasConsumer = config.system.activationScripts ? consumeBootstrapPassword;
  userDeps = config.system.activationScripts.users.deps;
  consumerDeps =
    if config.system.activationScripts ? consumeBootstrapPassword
    then config.system.activationScripts.consumeBootstrapPassword.deps
    else [ ];
  passwordSources = {
    inherit (config.users.users.mei)
      password
      initialPassword
      hashedPassword
      initialHashedPassword
      hashedPasswordFile
      ;
  };
}
