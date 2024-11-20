{ writeArgparseScriptBin, standalone ? false, color-prints }:
let
  pkgname = "anix-version";
  description = "Get the current anixpkgs version of the operating system.";
  long-description = ''
    usage: ${pkgname}
  '';
  usage_str = ''
    ${long-description}
    ${description}
  '';
  printYellow = "${color-prints}/bin/echo_yellow";
in (writeArgparseScriptBin pkgname usage_str [ ] ''
  ${if !standalone then
    ''echo -n "$(nix-store -q /nix/var/nix/profiles/system | cut -c 12-) ("''
  else
    ""}
  ${printYellow} ${
    if !standalone then "-n" else ""
  } "$(cat ~/.anix-version)-$(cat ~/.anix-meta)"
  ${if !standalone then ''echo ")"'' else ""}
'') // {
  meta = {
    inherit description;
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
