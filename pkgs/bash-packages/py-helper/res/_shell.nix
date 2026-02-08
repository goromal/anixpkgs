let
  pkgs = import (fetchTarball (
    "https://github.com/goromal/anixpkgs/archive/refs/tags/vREPLACEME.tar.gz"
  )) { };
  python = pkgs.python311;
  pythonPackages = python.pkgs;
  application = pythonPackages.callPackage ./default.nix { };
  pythonEnv = python.withPackages (ps: application.propagatedBuildInputs);
in
with pkgs;
mkShell {
  buildInputs = [ pythonEnv ];
  shellHook = ''
    echo "Executing shellHook"
    pyversion=python$(python --version | awk '{print $2}' | awk -F . '{print $1 "." $2}')
    echo "Found python version $pyversion"
    echo "Deleting old nixcopy and venv"
    rm -rf nixcopy venv  && mkdir nixcopy
    echo "Copying ${application} to $PWD/nixcopy"
    cp -r ${application}/* ./nixcopy
    chmod -R +w ./nixcopy
    echo "Parsing nix output for modules and entry points"
    modules="$(ls nixcopy/lib/$pyversion/site-packages | grep -v dist-info | tr '\n' ' ')"
    if [[ -d nixcopy/bin ]]
    then
      entrypoints="$(ls nixcopy/bin)"  > /dev/null
      echo "Found entry points: $entrypoints"
    fi
    if [[ "$modules" == "" ]] 
    then
      echo -e "\033[1;33mWARNING: NO TOP LEVEL MODULES FOUND\033[0m"
    else
      echo "Found modules: $modules"
    fi
    for entry in $entrypoints
    do
      echo "  Patching paths in $PWD/nixcopy/bin/$entry and $PWD/nixcopy/bin/.$entry-wrapped"
      sed -i -e s:${application}:$PWD/nixcopy:g  ./nixcopy/bin/$entry ./nixcopy/bin/.$entry-wrapped
      sed -i "4 i import sys;sys.path.append('$PWD/venv/lib/$pyversion/site-packages')" ./nixcopy/bin/.$entry-wrapped 
    done
    for mod in $modules
    do
      echo "  Linking $PWD/nixcopy/lib/$pyversion/site-packages/$mod to $PWD/$mod"
      rm -rf $PWD/nixcopy/lib/$pyversion/site-packages/$mod
      ln -s $PWD/$mod $PWD/nixcopy/lib/$pyversion/site-packages/$mod
    done
    echo "Creating and activating venv"
    python -m venv venv
    . venv/bin/activate
    echo "Adding $PWD/nixcopy/bin to PATH"
    PATH=$PWD/nixcopy/bin:$PATH
    echo "Adding $PWD/nixcopy/lib/$pyversion/site-packages to PYTHONPATH"
    PYTHONPATH=$PWD/nixcopy/lib/$pyversion/site-packages:$PYTHONPATH
    # ^modules in project root will be imported if running a script from that direcotry.

    echo "Finished executing shellHook"
  '';
}
