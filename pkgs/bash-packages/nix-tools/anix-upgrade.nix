{ writeShellScriptBin, callPackage, color-prints }:
let
  pkgname = "anix-upgrade";
  description = "Upgrade the operating system.";
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
  if [[ "$local" == "1" ]]; then
    localVar=true
  else
    localVar=false
  fi
  if [[ ! -z "$version" ]]; then
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; rev = "refs/heads/v'"''${version}"'"; }' -o anixpkgs
  elif [[ ! -z "$commit" ]]; then
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; rev = "'"$commit"'"; }' -o anixpkgs
  elif [[ ! -z "$branch" ]]; then
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "'"$branch"'"; }' -o anixpkgs
  else
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "master"; }' -o anixpkgs
  fi
  ${printYellow} "Upgrading to NixOS $(cat anixpkgs/NIXOS_VERSION) with anixpkgs version $(cat anixpkgs/ANIX_VERSION)..."
  if [[ "$boot" == "1" ]]; then
    sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild boot && ${printYellow} "Reboot for changes to take effect."
  else
    sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch && ${printYellow} "Done."
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
