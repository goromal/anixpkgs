{ writeArgparseScriptBin, color-prints, redirects }:
let
  pkgname = "git-cc";
  printErr = "${color-prints}/bin/echo_red";
  printGrn = "${color-prints}/bin/echo_green";
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} repo_dir des_dir

  Recursively backup a git repository (and its submodules) to a new, git-less source tree.
  Effectively wraps up an arbitrarily complex git repo into a flat-packaged mass of code.
'' [ ] ''
  if [[ -z "$1" ]]; then
      ${printErr} "No repo_dir provided."
      exit 1
  fi
  if [[ -z "$2" ]]; then
      ${printErr} "No des_dir provided."
      exit 1
  fi

  BASE_DIR="$1"
  if [[ "$BASE_DIR" != /* ]]; then
  BASE_DIR="$PWD/$BASE_DIR"
  fi

  DEST_DIR="$2"
  if [[ "$DEST_DIR" != /* ]]; then
  DEST_DIR="$PWD/$DEST_DIR"
  fi

  # Recursive function: copy all git-indexed, non-submodule files and return relative paths to all submodules
  image_repo() {
      # PATHS NEED TO BE ABSOLUTE
      local -n _basedirs=$1
      ms_bdir="$2"
      ms_ddir="$3"
      
      BDIR="''${_basedirs[0]}"
      DDIR=`echo "$BDIR" | sed "s#''${ms_bdir}#''${ms_ddir}#"`

      ${printGrn} "''${BDIR}"

      # create destination dir if it doesn't exist
      mkdir -p "''${DDIR}"

      # Get list of all non-submodule indexed files from base dir using symmetric difference
      pushd "''${BDIR}" ${redirects.suppress_all}
      IDXFLIST=`sort <(git ls-files) <(git config --file .gitmodules --get-regexp path | awk '{ print $2 }') | uniq -u`

      # Copy files and structures to destination dir
      for idxfile in $(echo $IDXFLIST) ; do
          fromfile="$BDIR/$idxfile"
          destfile="$DDIR/$idxfile"
          destfdir=$(dirname "$destfile")
          mkdir -p "$destfdir"
          cp -av "$fromfile" "$destfile" ${redirects.suppress_all}
      done

      # remove base dir and reconstruct to avoid index gaps
      unset _basedirs[0]
      new_basedirs=()
      for i in "''${_basedirs[@]}"; do
          new_basedirs+=( "$i" )
      done
      _basedirs=("''${new_basedirs[@]}")

      # add all submodules to base dir list
      for sbmdl in $(git config --file .gitmodules --get-regexp path | awk '{ print $2 }') ; do
          _basedirs+=("''${PWD}/$sbmdl")
      done
      popd ${redirects.suppress_all}
  }

  MS_BASEDIR="''${BASE_DIR}"
  BASEDIRS=("''${MS_BASEDIR}")
  MS_DESTDIR="''${DEST_DIR}"

  while [ ''${#BASEDIRS[@]} -ne 0 ] ; do
      image_repo BASEDIRS "''${MS_BASEDIR}" "''${MS_DESTDIR}"
  done
'') // {
  meta = {
    description = "Create a carbon copy of a Git repo, but with Git removed.";
    longDescription = ''
      ```
      usage: git-cc repo_dir des_dir

      Recursively backup a git repository (and its submodules) to a new, git-less source tree.
      Effectively wraps up an arbitrarily complex git repo into a flat-packaged mass of code.
      ```
    '';
  };
}
