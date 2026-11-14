{ pkgs }:

# Glances 4.5.9 replaced vulnerable python-jose with PyJWT. The NixOS 26.05
# channel still packages 4.5.5 and pulls python-jose into every system closure.
pkgs.glances.overridePythonAttrs (old: {
  version = "4.5.9";
  src = pkgs.fetchFromGitHub {
    owner = "nicolargo";
    repo = "glances";
    tag = "v4.5.9";
    hash = "sha256-CvT9GQ29xXTVxC7V2nGmfDhHLsAtF61+XMMLG8cmHww=";
  };
  dependencies = pkgs.lib.filter (dep: (dep.pname or "") != "python-jose") old.dependencies ++ [
    pkgs.python3Packages.pyjwt
  ];
  # REST tests connect to local servers, which the Nix sandbox does not expose
  # reliably. The remaining two tests depend on host CPU and smartctl behavior.
  disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
    "tests/test_browser_restful.py"
    "tests/test_restful.py"
  ];
  disabledTests = (old.disabledTests or [ ]) ++ [
    "test_phys_core_returns_int"
    "test_missing_smartctl_returns_no_device"
  ];
})
