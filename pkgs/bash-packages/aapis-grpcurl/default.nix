{
  stdenv,
  makeWrapper,
  grpcurl,
  apis-fds,
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
  meta = {
    description = "Interact with gRPC servers using custom APIs.";
    longDescription = ''
      A wrapped version of the [grpcurl](https://github.com/fullstorydev/grpcurl) tool that points to [my custom API](https://github.com/goromal/aapis) definitions.

      Since I use gRPC for inter-process communication for most simulated robot platform personal projects, this is a useful CLI tool for debugging.

      Example:

      ```bash
      aapis-grpcurl -plaintext -d '{"result": {"year": 2025,"month": 11, "day": 15, "survey_name": "Your Survey", "results": [{"question_name": "Second question", "result": 3}]}}' localhost:60060 aapis.tactical.v1.TacticalService/SubmitSurveyResult
      ```
    '';
  };
}
