{
  writeArgparseScriptBin,
  sunnyside,
  file,
  redirects,
}:
let
  pkgname = "sread";
  cpath = "/.c/c";
in
(writeArgparseScriptBin pkgname
  ''
    usage: ${pkgname} [opts] file

    Read a secure file.

    Options:
      -c /path/to/cipher (default: ${cpath})
  ''
  [
    {
      var = "CIPHER";
      isBool = false;
      default = cpath;
      flags = "-c";
    }
  ]
  ''
    if [[ -z "$1" ]]; then
      echo ""
      exit
    elif [[ "$1" != *.tyz ]]; then
      echo ""
      exit
    elif [[ ! -f "$1" ]]; then
      echo ""
      exit
    elif [[ ! -f "$CIPHER" ]]; then
      echo ""
      exit
    fi

    cchar=$([ -s "$CIPHER" ] && ${file}/bin/file --mime-type -b "$CIPHER" | grep -q '^text/' && cat "$CIPHER" || echo -n " ")
    TMPDIR=$(mktemp -d)
    UCNAME=$(basename $1)
    CNAME=$(basename $1 .tyz)

    cp "$1" $TMPDIR
    pushd $TMPDIR ${redirects.suppress_all}
    ${sunnyside}/bin/sunnyside --target "$UCNAME" --shift 0 --key "$cchar" ${redirects.suppress_all}
    cat "$CNAME"
    popd ${redirects.suppress_all}
    rm -r $TMPDIR
  ''
)
// {
  meta = {
    description = "Read secure files.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
