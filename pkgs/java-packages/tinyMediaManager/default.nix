{ lib, stdenv, jdk17, maven, libmediainfo, libzen, pkg-src }:
stdenv.mkDerivation rec {
  pname = "tinymediamanager";
  version = "custom";

  src = pkg-src;

  nativeBuildInputs = [ maven jdk17 ];
  buildInputs = [ libmediainfo libzen ];

  # Maven puts build outputs under ./target
  buildPhase = ''
    export JAVA_HOME=${jdk17}
    mvn dependency:build-classpath -Dmdep.outputFile=cp.txt
    mkdir -p native/linux
    ln -sf ${libmediainfo}/lib/libmediainfo.so native/linux/libmediainfo.so
    ln -sf ${libzen}/lib/libzen.so native/linux/libzen.so
  '';

  installPhase = ''
    mkdir -p $out/{bin,lib}
    cp -r target/classes $out/lib/
    cp cp.txt $out/lib/

    # Create a wrapper script to launch the app
    cat > $out/bin/tinymediamanager <<EOF
    #!/usr/bin/env bash
    export LD_LIBRARY_PATH=${libmediainfo}/lib:${libzen}/lib:\$LD_LIBRARY_PATH
    java -cp "$out/lib/classes:\$(cat $out/lib/cp.txt)" org.tinymediamanager.TinyMediaManager "\$@"
    EOF
    chmod +x $out/bin/tinymediamanager
  '';

  meta = with lib; {
    description = "TinyMediaManager (custom Java package)";
    platforms = platforms.linux;
  };
}
