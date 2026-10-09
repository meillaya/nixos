let
  inherit (builtins)
    bitAnd
    bitOr
    bitXor
    div
    elemAt
    foldl'
    genList
    length
    stringLength
    substring
    ;

  mod = value: divisor: value - div value divisor * divisor;
  pow2 = n: if n == 0 then 1 else 2 * pow2 (n - 1);
  u32 = n: mod n 4294967296;
  shr = value: bits: div value (pow2 bits);
  shl = value: bits: u32 (value * pow2 bits);
  rotr = value: bits: bitOr (shr value bits) (shl value (32 - bits));
  xor3 =
    a: b: c:
    bitXor (bitXor a b) c;
  not32 = value: bitXor value 4294967295;
  add32 = values: u32 (foldl' (sum: value: sum + value) 0 values);

  choose =
    x: y: z:
    bitXor (bitAnd x y) (bitAnd (not32 x) z);
  majority =
    x: y: z:
    xor3 (bitAnd x y) (bitAnd x z) (bitAnd y z);
  bigSigma0 = x: xor3 (rotr x 2) (rotr x 13) (rotr x 22);
  bigSigma1 = x: xor3 (rotr x 6) (rotr x 11) (rotr x 25);
  smallSigma0 = x: xor3 (rotr x 7) (rotr x 18) (shr x 3);
  smallSigma1 = x: xor3 (rotr x 17) (rotr x 19) (shr x 10);

  roundConstants = [
    1116352408
    1899447441
    3049323471
    3921009573
    961987163
    1508970993
    2453635748
    2870763221
    3624381080
    310598401
    607225278
    1426881987
    1925078388
    2162078206
    2614888103
    3248222580
    3835390401
    4022224774
    264347078
    604807628
    770255983
    1249150122
    1555081692
    1996064986
    2554220882
    2821834349
    2952996808
    3210313671
    3336571891
    3584528711
    113926993
    338241895
    666307205
    773529912
    1294757372
    1396182291
    1695183700
    1986661051
    2177026350
    2456956037
    2730485921
    2820302411
    3259730800
    3345764771
    3516065817
    3600352804
    4094571909
    275423344
    430227734
    506948616
    659060556
    883997877
    958139571
    1322822218
    1537002063
    1747873779
    1955562222
    2024104815
    2227730452
    2361852424
    2428436474
    2756734187
    3204031479
    3329325298
  ];

  initialHash = [
    1779033703
    3144134277
    1013904242
    2773480762
    1359893119
    2600822924
    528734635
    1541459225
  ];

  take = count: values: genList (index: elemAt values index) count;
  drop = count: values: genList (index: elemAt values (index + count)) (length values - count);

  byteWord =
    bytes: offset:
    add32 [
      (shl (elemAt bytes offset) 24)
      (shl (elemAt bytes (offset + 1)) 16)
      (shl (elemAt bytes (offset + 2)) 8)
      (elemAt bytes (offset + 3))
    ];

  extendWords =
    words: index:
    if index == 64 then
      words
    else
      extendWords (
        words
        ++ [
          (add32 [
            (smallSigma1 (elemAt words (index - 2)))
            (elemAt words (index - 7))
            (smallSigma0 (elemAt words (index - 15)))
            (elemAt words (index - 16))
          ])
        ]
      ) (index + 1);

  compress =
    hash: bytes:
    let
      initialWords = genList (index: byteWord bytes (index * 4)) 16;
      words = extendWords initialWords 16;
      state = foldl' (
        current: index:
        let
          a = elemAt current 0;
          b = elemAt current 1;
          c = elemAt current 2;
          d = elemAt current 3;
          e = elemAt current 4;
          f = elemAt current 5;
          g = elemAt current 6;
          h = elemAt current 7;
          temporary1 = add32 [
            h
            (bigSigma1 e)
            (choose e f g)
            (elemAt roundConstants index)
            (elemAt words index)
          ];
          temporary2 = add32 [
            (bigSigma0 a)
            (majority a b c)
          ];
        in
        [
          (add32 [
            temporary1
            temporary2
          ])
          a
          b
          c
          (add32 [
            d
            temporary1
          ])
          e
          f
          g
        ]
      ) hash (genList (index: index) 64);
    in
    genList (
      index:
      add32 [
        (elemAt hash index)
        (elemAt state index)
      ]
    ) 8;

  appendZeroes = count: values: values ++ genList (_: 0) count;
  bigEndian64 = value: genList (index: mod (shr value ((7 - index) * 8)) 256) 8;
  pad =
    bytes:
    let
      withMarker = bytes ++ [ 128 ];
      zeroCount = mod (56 - mod (length withMarker) 64 + 64) 64;
    in
    appendZeroes zeroCount withMarker ++ bigEndian64 (length bytes * 8);

  chunks =
    size: values:
    if values == [ ] then [ ] else [ (take size values) ] ++ chunks size (drop size values);

  wordBytes = word: genList (index: mod (shr word ((3 - index) * 8)) 256) 4;
  sha256Bytes =
    bytes: builtins.concatLists (map wordBytes (foldl' compress initialHash (chunks 64 (pad bytes))));

  alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  alphabetIndex =
    character:
    let
      go =
        index:
        if index == stringLength alphabet then
          null
        else if substring index 1 alphabet == character then
          index
        else
          go (index + 1);
    in
    go 0;

  decodeQuartet =
    quartet:
    let
      c0 = substring 0 1 quartet;
      c1 = substring 1 1 quartet;
      c2 = substring 2 1 quartet;
      c3 = substring 3 1 quartet;
      a = alphabetIndex c0;
      b = alphabetIndex c1;
      c = if c2 == "=" then 0 else alphabetIndex c2;
      d = if c3 == "=" then 0 else alphabetIndex c3;
      valid = a != null && b != null && c != null && d != null && !(c2 == "=" && c3 != "=");
      packed = if valid then a * 262144 + b * 4096 + c * 64 + d else 0;
    in
    if !valid then
      null
    else
      [ (mod (shr packed 16) 256) ]
      ++ (if c2 == "=" then [ ] else [ (mod (shr packed 8) 256) ])
      ++ (if c3 == "=" then [ ] else [ (mod packed 256) ]);

  decodeBase64 =
    encoded:
    let
      size = stringLength encoded;
      go =
        offset: result:
        if offset == size then
          result
        else
          let
            decoded = decodeQuartet (substring offset 4 encoded);
          in
          if decoded == null then null else go (offset + 4) (result ++ decoded);
    in
    if size == 0 || mod size 4 != 0 then null else go 0 [ ];

  alphabetChar = index: substring index 1 alphabet;
  encodeTriplet =
    bytes:
    let
      count = length bytes;
      a = elemAt bytes 0;
      b = if count > 1 then elemAt bytes 1 else 0;
      c = if count > 2 then elemAt bytes 2 else 0;
      packed = a * 65536 + b * 256 + c;
    in
    alphabetChar (mod (shr packed 18) 64)
    + alphabetChar (mod (shr packed 12) 64)
    + (if count > 1 then alphabetChar (mod (shr packed 6) 64) else "=")
    + (if count > 2 then alphabetChar (mod packed 64) else "=");

  encodeBase64 =
    bytes:
    if bytes == [ ] then
      ""
    else
      encodeTriplet (take (if length bytes < 3 then length bytes else 3) bytes)
      + encodeBase64 (drop (if length bytes < 3 then length bytes else 3) bytes);

  expectedPrefix = [
    0
    0
    0
    11
    115
    115
    104
    45
    101
    100
    50
    53
    53
    49
    57
    0
    0
    0
    32
  ];
  hasPrefix =
    prefix: values:
    length values >= length prefix && genList (index: elemAt values index) (length prefix) == prefix;

  parseEd25519 =
    publicKey:
    if !builtins.isString publicKey then
      null
    else
      let
        match = builtins.match "ssh-ed25519 ([A-Za-z0-9+/]+={0,2})" publicKey;
      in
      if match == null then
        null
      else
        let
          encoded = elemAt match 0;
          decoded = decodeBase64 encoded;
        in
        if
          decoded == null
          || encodeBase64 decoded != encoded
          || length decoded != 51
          || !hasPrefix expectedPrefix decoded
        then
          null
        else
          decoded;

  stripPadding =
    encoded:
    if stringLength encoded > 0 && substring (stringLength encoded - 1) 1 encoded == "=" then
      stripPadding (substring 0 (stringLength encoded - 1) encoded)
    else
      encoded;
in
{
  inherit decodeBase64 encodeBase64 sha256Bytes;

  isCanonicalEd25519PublicKey = publicKey: parseEd25519 publicKey != null;

  sshEd25519Fingerprint =
    publicKey:
    let
      decoded = parseEd25519 publicKey;
    in
    if decoded == null then null else "SHA256:" + stripPadding (encodeBase64 (sha256Bytes decoded));
}
