{
  lib,
  buildGoModule,
  go_1_26,
  pkg-src,
}:
(buildGoModule.override { go = go_1_26; }) {
  pname = "ladder";
  version = "0.0.22";
  src = pkg-src;
  vendorHash = "sha256-E7bxFMSeUe8F7AWubstmk+9lfiTJIl8lcU3aShjcR5M=";
  postInstall = ''
    mv $out/bin/cmd $out/bin/ladder
  '';
  meta = {
    description = "HTTP web proxy for bypassing paywalls.";
    longDescription = ''
      Written in Go. [Repository](https://github.com/everywall/ladder)
    '';
  };
}
