{
  lib,
  stdenv,
  makeWrapper,
  gradle,
  openjdk17,
  pkg-src,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "microxrceddsgen";
  version = "4.7.1";

  src = pkg-src;

  # The pinned IDL-Parser submodule predates Gradle 8, where the Jar task's
  # `classifier` property was replaced by `archiveClassifier`.
  postPatch = ''
    substituteInPlace thirdparty/IDL-Parser/build.gradle \
      --replace-fail "classifier = 'sources'" "archiveClassifier = 'sources'" \
      --replace-fail "classifier 'sources'" ""
  '';

  nativeBuildInputs = [
    gradle
    openjdk17
    makeWrapper
  ];

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    inherit (finalAttrs) pname;
    data = ./deps.json;
  };

  # The source is fetched with submodules already present; there is no .git,
  # so the git-based submodulesUpdate task must be skipped.
  gradleFlags = [
    "-x"
    "submodulesUpdate"
  ];

  gradleBuildTask = "assemble";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/microxrceddsgen/java
    cp share/microxrceddsgen/java/microxrceddsgen.jar $out/share/microxrceddsgen/java/

    makeWrapper ${openjdk17}/bin/java $out/bin/microxrceddsgen \
      --add-flags "-jar $out/share/microxrceddsgen/java/microxrceddsgen.jar"

    runHook postInstall
  '';

  # The IDL-Parser submodule is built via a nested GradleBuild task, so its
  # dependencies must be recorded into the MITM cache separately.
  postGradleUpdate = ''
    cd thirdparty/IDL-Parser
    gradleFlags=
    gradle nixDownloadDeps
  '';

  meta = {
    description = "eProsima Micro-XRCE-DDS IDL code generator tool (ArduPilot fork)";
    mainProgram = "microxrceddsgen";
    homepage = "https://github.com/ardupilot/Micro-XRCE-DDS-Gen";
    license = lib.licenses.asl20;
  };
})
