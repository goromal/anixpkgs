{ writeArgparseScriptBin, color-prints, browser-aliases ? null
, standalone ? false, git-cc }:
let
  pkgname = "anix-upgrade";
  description = "Upgrade the operating system${
      if browser-aliases == null then "." else " and view the delta."
    }${if standalone then " [HOME-MANAGER VERSION]" else " [NIXOS VERSION]"}";
  long-description = ''
    usage: ${pkgname} [-v|--version VERSION;-c|--commit COMMIT;-b|--branch BRANCH;-s|--source SOURCETREE] [--local] [--boot]
  '';
  usage_str = ''
    ${long-description}
    ${description}

    For this to work properly, your configuration.nix file or home.nix file must be symlinked to some configuration file in ~/sources/anixpkgs (which is generated by this program).
  '';
  printYellow = "${color-prints}/bin/echo_yellow";
  printError = "${color-prints}/bin/echo_red";
in (writeArgparseScriptBin pkgname usage_str [
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
    var = "source";
    isBool = false;
    default = "";
    flags = "-s|--source";
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
] ''
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
  if [[ -d anixpkgs ]]; then
    if [[ -L anixpkgs ]]; then
      ${printYellow} "Removing existing symlink."
      rm anixpkgs
    else
      ${printYellow} "Removing existing directory."
      rm -rf anixpkgs
    fi
  fi
  if [[ ! -z "$version" ]]; then
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/tags/v'"''${version}"'"; }' -o anixpkgs
  elif [[ ! -z "$commit" ]]; then
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "'"$commit"'"; }' -o anixpkgs
  elif [[ ! -z "$branch" ]]; then
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/heads/'"$branch"'"; }' -o anixpkgs
  elif [[ ! -z "$source" ]]; then
    if [[ "$source" != /* ]]; then
      ${printError} "Please provide an absolute path to the source tree."
      exit 1
    fi
    ${git-cc}/bin/git-cc "$source" anixpkgs
    if [[ "$localVar" == "true" ]]; then
      sed -i 's|local-build = false;|local-build = true;|g' anixpkgs/pkgs/nixos/dependencies.nix
    fi
  else
    nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/heads/master"; }' -o anixpkgs
  fi
  vdest=$(cat anixpkgs/ANIX_VERSION)
  ${printYellow} "Upgrading anixpkgs from $vcurr -> $vdest (NixOS $(cat anixpkgs/NIXOS_VERSION))..."
  if [[ "$boot" == "1" ]]; then
    ${
      if standalone == false then ''
        sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild boot && ${printYellow} "Reboot for changes to take effect."
      '' else ''
        ${printYellow} "Ignoring boot flag for home switch" && home-manager switch && ${printYellow} "Done."
      ''
    }
  else
    ${
      if standalone == false then ''
        sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch && ${printYellow} "Done."
      '' else ''
        home-manager switch && ${printYellow} "Done."
      ''
    }
  fi
  if [[ "$vcurr" != "Local Build" && "$local" == "0" ]]; then
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
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
