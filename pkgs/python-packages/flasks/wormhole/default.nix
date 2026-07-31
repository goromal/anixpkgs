{
  buildPythonPackage,
  setuptools,
  pytestCheckHook,
  pkg-src,
}:
buildPythonPackage rec {
  pname = "wormhole";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/wormhole";
  nativeCheckInputs = [ pytestCheckHook ];
  meta = {
    description = "Local-or-remote (ssh) file operations shared by the flasks UIs, plus a `wormhole` CLI.";
    longDescription = ''
      Stdlib-only helpers for listing, reading, writing, and deleting files
      either on the local filesystem or on a remote host over ssh (BatchMode,
      argv-array subprocess calls, shlex-quoted remote paths). Consuming
      services must have openssh on their PATH for remote operations.

      The `wormhole` command exposes the host resolver used for LAN/VPN
      access: `wormhole resolve <name>.local` prints the direct LAN IP from
      ~/secrets/<name>/i.txt (needed over the VPN, where mDNS does not
      propagate), or echoes the host back unchanged.
    '';
    autoGenUsageCmd = "--help";
    subCmds = [
      "resolve"
    ];
  };
}
