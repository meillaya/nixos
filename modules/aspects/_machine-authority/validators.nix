let
  crypto = import ./crypto.nix;

  sort = builtins.sort builtins.lessThan;
  optional = condition: value: if condition then [ value ] else [ ];
  all = predicate: values: builtins.all predicate values;
  elem = value: values: builtins.elem value values;
  inherit (builtins)
    isAttrs
    isBool
    isInt
    isList
    isString
    ;

  projectionFields = [
    "hostId"
    "target"
    "system"
    "role"
    "identity"
    "location"
    "display"
    "boot"
    "storage"
    "publicTrust"
    "secretTrust"
    "cpuVendor"
    "firmware"
    "kernel"
    "gpu"
    "network"
    "devices"
    "capabilities"
    "ddcConnectors"
    "remoteInstall"
    "platformExpectations"
  ];

  physicalCapabilityKeys = [
    "reboot"
    "rollback"
    "firmware"
    "microcode"
    "network.ethernet"
    "network.usb-ethernet"
    "network.usb-tether"
    "network.wifi"
    "recovery.local-console"
    "gpu"
    "audio"
    "bluetooth"
    "power"
    "suspend"
    "ddc"
    "session"
    "portal-obs"
    "theme-kitty"
  ];
  capabilityKeys = sort (
    [
      "install.direct"
      "install.remote"
    ]
    ++ physicalCapabilityKeys
  );
  networkCapabilityKeys = sort [
    "network.ethernet"
    "network.usb-ethernet"
    "network.usb-tether"
    "network.wifi"
  ];
  wiredRemoteCapabilityKeys = sort [
    "network.ethernet"
    "network.usb-ethernet"
    "network.usb-tether"
  ];
  alwaysRequiredCapabilityKeys = sort [
    "install.direct"
    "reboot"
    "rollback"
    "firmware"
    "microcode"
    "recovery.local-console"
    "session"
    "portal-obs"
    "theme-kitty"
  ];

  firmwareNotRequiredPciClasses = [
    "06:00:00"
    "06:04:00"
  ];

  keysExact = expected: value: isAttrs value && builtins.attrNames value == sort expected;
  matches = regex: value: isString value && builtins.match regex value != null;
  enum = values: value: isString value && elem value values;
  nonNegativeInt = value: isInt value && value >= 0;
  positiveInt = value: isInt value && value > 0;
  sha256 = matches "[0-9a-f]{64}";

  unique =
    values:
    if values == [ ] then
      true
    else
      let
        first = builtins.head values;
        rest = builtins.tail values;
      in
      !(elem first rest) && unique rest;

  sortedUniqueStrings =
    values: isList values && all isString values && values == sort values && unique values;

  sortedUniqueBy =
    field: values:
    isList values
    && all (
      row: isAttrs row && builtins.hasAttr field row && isString (builtins.getAttr field row)
    ) values
    && (
      let
        fields = map (row: builtins.getAttr field row) values;
      in
      fields == sort fields && unique fields
    );

  gcd = a: b: if b == 0 then a else gcd b (a - builtins.div a b * b);

  validIdentity =
    value:
    keysExact [ "name" "home" "uid" "gid" ] value
    && matches "[a-z_][a-z0-9_-]{0,31}" value.name
    && matches "/[^[:cntrl:]]+" value.home
    && nonNegativeInt value.uid
    && value.uid <= 2147483647
    && nonNegativeInt value.gid
    && value.gid <= 2147483647;

  validLocation =
    value:
    keysExact [ "timeZone" "locale" "keymap" "xkb" ] value
    && matches "[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)+" value.timeZone
    && matches "[A-Za-z][A-Za-z0-9_@.-]{1,63}" value.locale
    && matches "[A-Za-z0-9_-]{1,32}" value.keymap
    && matches "[A-Za-z0-9_-]{1,32}" value.xkb;

  validDisplay =
    value:
    keysExact [ "scale" ] value
    && keysExact [ "numerator" "denominator" ] value.scale
    && positiveInt value.scale.numerator
    && positiveInt value.scale.denominator
    && gcd value.scale.numerator value.scale.denominator == 1
    && value.scale.numerator >= value.scale.denominator
    && value.scale.numerator <= 4 * value.scale.denominator;

  validBoot =
    value:
    isAttrs value
    && value ? state
    && (
      (value.state == "disabled" && keysExact [ "state" ] value)
      || (
        value.state == "uefi"
        && keysExact [ "state" "secureBoot" "configurationLimit" ] value
        && value.secureBoot == false
        && value.configurationLimit == 10
      )
    );

  safeDiskById =
    value:
    matches "[A-Za-z0-9][A-Za-z0-9._:+-]{0,254}" value && builtins.match ".*-part[0-9]+" value == null;

  validStorage =
    value:
    isAttrs value
    && value ? profile
    && (
      (value.profile == "none" && keysExact [ "profile" ] value)
      || (
        value.profile == "single-gpt-btrfs"
        && keysExact [ "profile" "diskById" "expected" ] value
        && safeDiskById value.diskById
        && keysExact [ "sizeBytes" "logicalSectorBytes" "modelSha256" "serialSha256" ] value.expected
        && positiveInt value.expected.sizeBytes
        && elem value.expected.logicalSectorBytes [
          512
          4096
        ]
        && sha256 value.expected.modelSha256
        && sha256 value.expected.serialSha256
      )
    );

  validPublicTrust =
    value:
    isAttrs value
    && value ? state
    && (
      (value.state == "disabled" && keysExact [ "state" ] value)
      || (
        value.state == "enrolled"
        && keysExact [
          "state"
          "installAuthorizerPrincipal"
          "installAuthorizerPublicKey"
          "installAuthorizerFingerprint"
          "permanentLoginPublicKey"
          "permanentLoginFingerprint"
          "finalHostPublicKey"
          "finalHostFingerprint"
        ] value
        && matches "[A-Za-z0-9._-]+" value.installAuthorizerPrincipal
        && crypto.isCanonicalEd25519PublicKey value.installAuthorizerPublicKey
        && crypto.isCanonicalEd25519PublicKey value.permanentLoginPublicKey
        && crypto.isCanonicalEd25519PublicKey value.finalHostPublicKey
        &&
          value.installAuthorizerFingerprint == crypto.sshEd25519Fingerprint value.installAuthorizerPublicKey
        && value.permanentLoginFingerprint == crypto.sshEd25519Fingerprint value.permanentLoginPublicKey
        && value.finalHostFingerprint == crypto.sshEd25519Fingerprint value.finalHostPublicKey
        && unique [
          value.installAuthorizerPublicKey
          value.permanentLoginPublicKey
          value.finalHostPublicKey
        ]
        && unique [
          value.installAuthorizerFingerprint
          value.permanentLoginFingerprint
          value.finalHostFingerprint
        ]
      )
    );

  ageRecipient = matches "age1[023456789acdefghjklmnpqrstuvwxyz]{58}";
  secretPath = matches "secrets/[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*";
  validCiphertext =
    value: keysExact [ "path" "sha256" ] value && secretPath value.path && sha256 value.sha256;

  validSecretTrust =
    value:
    isAttrs value
    && value ? state
    && (
      (value.state == "disabled" && keysExact [ "state" ] value)
      || (
        value.state == "enrolled"
        && keysExact [ "state" "hostAgeRecipient" "recoveryAgeRecipient" "ciphertexts" ] value
        && ageRecipient value.hostAgeRecipient
        && ageRecipient value.recoveryAgeRecipient
        && value.hostAgeRecipient != value.recoveryAgeRecipient
        && sortedUniqueBy "path" value.ciphertexts
        && value.ciphertexts != [ ]
        && all validCiphertext value.ciphertexts
      )
    );

  validFirmwareExpectationFor =
    pciClass: value:
    isAttrs value
    && value ? state
    && (
      (value.state == "driver-bound-no-load-failure" && keysExact [ "state" ] value)
      || (
        value.state == "not-required"
        && keysExact [ "state" "reason" ] value
        && value.reason == "device-has-no-loadable-firmware"
        && elem pciClass firmwareNotRequiredPciClasses
      )
    );

  validFirmwareRow =
    value:
    keysExact [ "logicalId" "pciClass" "expectedDriver" "firmwareExpectation" ] value
    && matches "[a-z][a-z0-9-]{0,63}" value.logicalId
    && matches "[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}" value.pciClass
    && matches "[A-Za-z0-9_-]{1,64}" value.expectedDriver
    && validFirmwareExpectationFor value.pciClass value.firmwareExpectation;

  validNetworkRow =
    value:
    keysExact [ "capability" "controllerClass" "expectedDriver" "firmwareExpectation" ] value
    && elem value.capability networkCapabilityKeys
    && matches "[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}" value.controllerClass
    && matches "[A-Za-z0-9_-]{1,64}" value.expectedDriver
    && validFirmwareExpectationFor value.controllerClass value.firmwareExpectation;

  validGpuDevice =
    value:
    value == null
    || (
      keysExact [ "expectedDriver" "expectedRendererDigest" ] value
      && matches "[A-Za-z0-9_-]{1,64}" value.expectedDriver
      && sha256 value.expectedRendererDigest
    );

  validDevices =
    value:
    isAttrs value
    && value ? state
    && (
      (value.state == "disabled" && keysExact [ "state" ] value)
      || (
        value.state == "enrolled"
        && keysExact [ "state" "firmware" "network" "gpu" "powerDaemon" ] value
        && sortedUniqueBy "logicalId" value.firmware
        && value.firmware != [ ]
        && all validFirmwareRow value.firmware
        && sortedUniqueBy "capability" value.network
        && all validNetworkRow value.network
        && validGpuDevice value.gpu
        && (value.powerDaemon == null || value.powerDaemon == "power-profiles-daemon")
      )
    );

  validCapabilityValue =
    value:
    isAttrs value
    && value ? state
    && (
      (value.state == "present" && keysExact [ "state" ] value)
      || (
        value.state == "absent"
        && keysExact [ "state" "reason" ] value
        && elem value.reason [
          "not-equipped"
          "unsupported"
          "deferred"
        ]
      )
    );

  validCapabilities =
    value:
    isAttrs value
    && value ? state
    && (
      (value.state == "disabled" && keysExact [ "state" ] value)
      || (
        value.state == "enrolled"
        && keysExact [ "state" "values" ] value
        && keysExact capabilityKeys value.values
        && all (key: validCapabilityValue value.values.${key}) capabilityKeys
      )
    );

  connectorFormat = matches "[A-Za-z]+-[A-Za-z0-9-]+";
  validDdcConnector =
    value:
    keysExact [ "connector" "i2cLocatorDigest" "sysfsConnectorDigest" ] value
    && connectorFormat value.connector
    && sha256 value.i2cLocatorDigest
    && sha256 value.sysfsConnectorDigest;

  validDdcConnectors = value: sortedUniqueBy "connector" value && all validDdcConnector value;

  validManagedApp =
    value:
    keysExact [ "bundleId" "appPathDigest" ] value
    && matches "[A-Za-z0-9][A-Za-z0-9.-]{1,254}" value.bundleId
    && sha256 value.appPathDigest;

  validPlatformExpectations =
    value:
    isAttrs value
    && value ? kind
    && (
      (value.kind == "none" && keysExact [ "kind" ] value)
      || (
        value.kind == "darwin"
        && keysExact [
          "kind"
          "networkServiceClass"
          "requiredTccServices"
          "managedApps"
          "kitty"
          "wallpaperPathDigest"
          "emacs"
        ] value
        && elem value.networkServiceClass [
          "wifi"
          "ethernet"
          "usb-ethernet"
          "tether"
        ]
        && sortedUniqueStrings value.requiredTccServices
        && all (matches "[A-Za-z0-9._-]{1,128}") value.requiredTccServices
        && sortedUniqueBy "bundleId" value.managedApps
        && all validManagedApp value.managedApps
        && keysExact [ "fontFamily" "fontDigest" "configDigest" "colorDigest" ] value.kitty
        && matches "[ -~]{1,128}" value.kitty.fontFamily
        && sha256 value.kitty.fontDigest
        && sha256 value.kitty.configDigest
        && sha256 value.kitty.colorDigest
        && sha256 value.wallpaperPathDigest
        && keysExact [ "pathDigest" "initDigest" "packageSetDigest" ] value.emacs
        && sha256 value.emacs.pathDigest
        && sha256 value.emacs.initDigest
        && sha256 value.emacs.packageSetDigest
      )
    );

  present = values: key: values.${key}.state == "present";

  validKnownRouting =
    machine:
    (
      machine.hostId == "remembrance"
      && machine.target == "nixosConfigurations.remembrance"
      && machine.system == "x86_64-linux"
      && machine.role == "workstation"
    )
    || (
      machine.hostId == "antagony"
      && machine.target == "nixosConfigurations.antagony"
      && machine.system == "x86_64-linux"
      && machine.role == "workstation"
    )
    || (
      machine.hostId == "entropy"
      && machine.target == "darwinConfigurations.entropy"
      && machine.system == "aarch64-darwin"
      && machine.role == "workstation"
    );

  operationallyDisabled =
    machine:
    machine.boot.state == "disabled"
    && machine.storage.profile == "none"
    && machine.publicTrust.state == "disabled"
    && machine.secretTrust.state == "disabled"
    && machine.devices.state == "disabled"
    && machine.capabilities.state == "disabled"
    && machine.ddcConnectors == [ ]
    && machine.remoteInstall == false;

  validCrossFields =
    machine:
    let
      isDarwin = machine.system == "aarch64-darwin";
      isPendingX86 = machine.system == "x86_64-linux" && machine.cpuVendor == "pending";
      isInstallable =
        machine.system == "x86_64-linux"
        && elem machine.cpuVendor [
          "GenuineIntel"
          "AuthenticAMD"
        ];
      capabilitiesEnrolled = machine.capabilities.state == "enrolled";
      values = if capabilitiesEnrolled then machine.capabilities.values else { };
      presentNetworks =
        if capabilitiesEnrolled then builtins.filter (present values) networkCapabilityKeys else [ ];
      declaredNetworks =
        if machine.devices.state == "enrolled" then
          map (row: row.capability) machine.devices.network
        else
          [ ];
      anyWiredRemote = capabilitiesEnrolled && builtins.any (present values) wiredRemoteCapabilityKeys;
      gpuPresent = capabilitiesEnrolled && present values "gpu";
      powerPresent = capabilitiesEnrolled && present values "power";
      ddcPresent = capabilitiesEnrolled && present values "ddc";
    in
    validKnownRouting machine
    && (
      if isDarwin then
        machine.cpuVendor == "Apple"
        && machine.firmware == "apple"
        && machine.kernel == "disabled"
        && machine.gpu == "apple-metal"
        && machine.network == "native-darwin"
        && machine.platformExpectations.kind == "darwin"
        && machine.publicTrust.state == "disabled"
        && (machine.secretTrust.state == "disabled" || machine.secretTrust.state == "enrolled")
        && machine.boot.state == "disabled"
        && machine.storage.profile == "none"
        && machine.devices.state == "disabled"
        && machine.capabilities.state == "disabled"
        && machine.ddcConnectors == [ ]
        && machine.remoteInstall == false
      else if isPendingX86 then
        machine.firmware == "disabled"
        && machine.kernel == "disabled"
        && machine.gpu == "disabled"
        && machine.network == "disabled"
        && machine.platformExpectations.kind == "none"
        && operationallyDisabled machine
      else if isInstallable then
        machine.boot.state == "uefi"
        && machine.storage.profile == "single-gpt-btrfs"
        && machine.publicTrust.state == "enrolled"
        && machine.secretTrust.state == "enrolled"
        && machine.firmware == "redistributable"
        && machine.kernel == "nixpkgs-default"
        && elem machine.gpu [
          "cpu-only"
          "generic-vulkan"
        ]
        && machine.network == "networkmanager"
        && machine.devices.state == "enrolled"
        && capabilitiesEnrolled
        && machine.platformExpectations.kind == "none"
        && all (present values) alwaysRequiredCapabilityKeys
        && machine.remoteInstall == present values "install.remote"
        && (!machine.remoteInstall || anyWiredRemote)
        && presentNetworks == declaredNetworks
        && (gpuPresent == (machine.devices.gpu != null))
        && (if gpuPresent then machine.gpu == "generic-vulkan" else machine.gpu == "cpu-only")
        && (
          if powerPresent then
            machine.devices.powerDaemon == "power-profiles-daemon"
          else
            machine.devices.powerDaemon == null
        )
        && (ddcPresent == (machine.ddcConnectors != [ ]))
      else
        false
    );

  validateUnsafe =
    machine:
    let
      topClosed = keysExact projectionFields machine;
      checks =
        optional (!topClosed) "machine object is not closed"
        ++ optional (!(topClosed && matches "[a-z][a-z0-9-]{0,63}" machine.hostId)) "invalid hostId"
        ++ optional (!(topClosed && isString machine.target)) "invalid target"
        ++ optional (
          !(topClosed && enum [ "x86_64-linux" "aarch64-darwin" ] machine.system)
        ) "invalid system"
        ++ optional (
          !(topClosed && enum [ "workstation" "qualifier" "evaluation" ] machine.role)
        ) "invalid role"
        ++ optional (!(topClosed && validIdentity machine.identity)) "invalid identity"
        ++ optional (!(topClosed && validLocation machine.location)) "invalid location"
        ++ optional (!(topClosed && validDisplay machine.display)) "invalid display"
        ++ optional (!(topClosed && validBoot machine.boot)) "invalid boot"
        ++ optional (!(topClosed && validStorage machine.storage)) "invalid storage"
        ++ optional (!(topClosed && validPublicTrust machine.publicTrust)) "invalid public trust"
        ++ optional (!(topClosed && validSecretTrust machine.secretTrust)) "invalid secret trust"
        ++ optional (
          !(topClosed && enum [ "pending" "GenuineIntel" "AuthenticAMD" "Apple" ] machine.cpuVendor)
        ) "invalid CPU vendor"
        ++ optional (
          !(topClosed && enum [ "disabled" "redistributable" "apple" ] machine.firmware)
        ) "invalid firmware policy"
        ++ optional (
          !(topClosed && enum [ "disabled" "nixpkgs-default" ] machine.kernel)
        ) "invalid kernel policy"
        ++ optional (
          !(topClosed && enum [ "disabled" "cpu-only" "generic-vulkan" "apple-metal" ] machine.gpu)
        ) "invalid GPU policy"
        ++ optional (
          !(topClosed && enum [ "disabled" "networkmanager" "native-darwin" ] machine.network)
        ) "invalid network policy"
        ++ optional (!(topClosed && validDevices machine.devices)) "invalid devices"
        ++ optional (!(topClosed && validCapabilities machine.capabilities)) "invalid capabilities"
        ++ optional (!(topClosed && validDdcConnectors machine.ddcConnectors)) "invalid DDC connectors"
        ++ optional (!(topClosed && isBool machine.remoteInstall)) "invalid remoteInstall"
        ++ optional (
          !(topClosed && validPlatformExpectations machine.platformExpectations)
        ) "invalid platform expectations"
        ++ optional (
          !(
            topClosed
            && validIdentity machine.identity
            && (
              (machine.system == "aarch64-darwin" && machine.identity.home == "/Users/${machine.identity.name}")
              || (machine.system != "aarch64-darwin" && machine.identity.home == "/home/${machine.identity.name}")
            )
          )
        ) "identity home does not match platform"
        ++ optional (
          !(
            topClosed
            && validBoot machine.boot
            && validStorage machine.storage
            && validPublicTrust machine.publicTrust
            && validSecretTrust machine.secretTrust
            && validDevices machine.devices
            && validCapabilities machine.capabilities
            && validDdcConnectors machine.ddcConnectors
            && validPlatformExpectations machine.platformExpectations
            && enum [ "pending" "GenuineIntel" "AuthenticAMD" "Apple" ] machine.cpuVendor
            && enum [ "disabled" "redistributable" "apple" ] machine.firmware
            && enum [ "disabled" "nixpkgs-default" ] machine.kernel
            && enum [ "disabled" "cpu-only" "generic-vulkan" "apple-metal" ] machine.gpu
            && enum [ "disabled" "networkmanager" "native-darwin" ] machine.network
            && isBool machine.remoteInstall
            && validCrossFields machine
          )
        ) "invalid platform or cross-field combination";
    in
    {
      valid = checks == [ ];
      errors = checks;
    };

  validate =
    machine:
    let
      attempted = builtins.tryEval (builtins.deepSeq (validateUnsafe machine) (validateUnsafe machine));
    in
    if attempted.success then
      attempted.value
    else
      {
        valid = false;
        errors = [ "malformed machine object" ];
      };
in
{
  inherit
    projectionFields
    physicalCapabilityKeys
    capabilityKeys
    networkCapabilityKeys
    wiredRemoteCapabilityKeys
    alwaysRequiredCapabilityKeys
    firmwareNotRequiredPciClasses
    validate
    ;

  assertValid =
    machine:
    let
      result = validate machine;
    in
    if result.valid then
      machine
    else
      throw "invalid machine declaration: ${builtins.concatStringsSep "; " result.errors}";

  project =
    machine:
    let
      result = validate machine;
      projected = builtins.listToAttrs (
        map (field: {
          name = field;
          value = machine.${field};
        }) projectionFields
      );
    in
    if result.valid then
      projected
    else
      throw "cannot project invalid machine declaration: ${builtins.concatStringsSep "; " result.errors}";

  inherit (crypto) isCanonicalEd25519PublicKey sshEd25519Fingerprint;
}
