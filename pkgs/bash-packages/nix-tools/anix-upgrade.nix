{ writeShellScriptBin, callPackage, color-prints, browser-aliases ? null }:
let
  pkgname = "anix-upgrade";
  description = "Upgrade the operating system${
      if browser-aliases == null then "." else " and view the delta."
    }";
  long-description = ''
    usage: ${pkgname} [-v|--version VERSION;-c|--commit COMMIT;-b|--branch BRANCH] [--local] [--boot]
  '';
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      ${long-description}
      ${description}
    '';
    optsWithVarsAndDefaults = [
      {
        var = "version";
        isBool = false;
        default = "";
        flags = "-v|--version";
      }
      {
        var = "commit";
        isBool = false;
        default = "";
        flags = "-c|--commit";
      }
      {
        var = "branch";
        isBool = false;
        default = "";
        flags = "-b|--branch";
      }
      {
        var = "local";
        isBool = true;
        default = "0";
        flags = "--local";
      }
      {
        var = "boot";
        isBool = true;
        default = "0";
        flags = "--boot";
      }
    ];
  };
  printYellow = "${color-prints}/bin/echo_yellow";
in (writeShellScriptBin pkgname ''
  ${argparse}
  cd ~/sources
  vcurr=$(cat ~/.anix-version)
  if [[ "$vcurr" != "Local Build" ]]; then
    vcurr=''${vcurr:1}
  fi
  if [[ "$local" == "1" ]]; then
    localVar=true
  else
    localVar=false
  fi
  if [[ ! -z "$version" ]]; then
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/tags/v'"''${version}"'"; }' -o anixpkgs
  elif [[ ! -z "$commit" ]]; then
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; rev = "'"$commit"'"; }' -o anixpkgs
  elif [[ ! -z "$branch" ]]; then
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/heads/'"$branch"'"; }' -o anixpkgs
  else
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/heads/master"; }' -o anixpkgs
  fi
  vdest=$(cat anixpkgs/ANIX_VERSION)
  ${printYellow} "Upgrading anixpkgs from $vcurr -> $vdest (NixOS $(cat anixpkgs/NIXOS_VERSION))..."
  if [[ "$boot" == "1" ]]; then
    sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild boot && ${printYellow} "Reboot for changes to take effect."
  else
    sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch && ${printYellow} "Done."
  fi
  if [[ "$vcurrfull" != "Local Build" && "$local" == "0" ]]; then
    ${
      if browser-aliases != null then
        "${browser-aliases}/bin/anix-compare $vcurr $vdest"
      else
        "echo ''"
    }
  fi
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
