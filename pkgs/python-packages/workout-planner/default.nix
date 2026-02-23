{
  buildPythonPackage,
  setuptools,
  pytestCheckHook,
  click,
  pyyaml,
  anthropic,
  easy-google-auth,
  pkg-src,
}:
buildPythonPackage rec {
  pname = "workout-planner";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = pkg-src;
  propagatedBuildInputs = [
    click
    pyyaml
    anthropic
    easy-google-auth
  ];
  doCheck = false; # No tests yet
  meta = {
    description = "AI-powered workout planner with Google Tasks integration.";
    longDescription = ''
      Generates personalized daily workout plans using Claude API and publishes
      them as Google Tasks. Tracks workout history and completion status.

      [Repository](https://github.com/goromal/workout-planner)
    '';
    autoGenUsageCmd = "--help";
    subCmds = [
      "generate"
      "history"
      "check-yesterday"
    ];
  };
}
