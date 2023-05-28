{ stdenv
, makeWrapper
, grpcurl
, apis-fds
}:
stdenv.mkDerivation {
    name = "aapis-grpcurl";
    nativeBuildInputs = [ makeWrapper ];
    buildInputs = [ grpcurl ];
    dontUnpack = true;
    installPhase = ''
        mkdir -p $out/bin
        makeWrapper ${grpcurl}/bin/grpcurl $out/bin/aapis-grpcurl --add-flags '-protoset ${apis-fds}'
    '';
}
