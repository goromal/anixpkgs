{ writeShellScriptBin, standalone ? false, callPackage, color-prints }:
let
  pkgname = "anix-version";
  description = "Get the current anixpkgs version of the operating system.";
  long-description = ''
    usage: ${pkgname}
  '';
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      ${long-description}
      ${description}
    '';
    optsWithVarsAndDefaults = [ ];
  };
  printYellow = "${color-prints}/bin/echo_yellow";
in (writeShellScriptBin pkgname ''
  ${argparse}
  ${if !standalone then "echo -n $(nix-store -q /nix/var/nix/profiles/system | cut -c 12-) (" else ""}
  ${printYellow} -n "$(cat ~/.anix-version)"
  echo ")"
'') // {
  meta = {
    inherit description;
    longDescription = ''
      ```bash
      ${long-description}
      ```  
    '';
  };
}
