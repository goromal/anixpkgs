{
  writeArgparseScriptBin,
  rsync,
  color-prints,
}:
let
  pkgname = "backup";
  description = "Rsync-based backup tool.";
in
(writeArgparseScriptBin pkgname
  ''
    usage: ${pkgname} --from SRC --to DST

    Mirror SRC to DST using rsync (archive, delete, checksum).

    Options:
      --from SRC    Source directory
      --to DST      Destination directory
  ''
  [
    {
      var = "from_dir";
      isBool = false;
      default = "";
      flags = "--from";
    }
    {
      var = "to_dir";
      isBool = false;
      default = "";
      flags = "--to";
    }
  ]
  ''
    if [[ -z "$from_dir" ]]; then
      >&2 ${color-prints}/bin/echo_red "Must specify --from."
      exit 1
    fi
    if [[ -z "$to_dir" ]]; then
      >&2 ${color-prints}/bin/echo_red "Must specify --to."
      exit 1
    fi
    ${rsync}/bin/rsync -a --delete --checksum --info=progress2 "$from_dir/" "$to_dir/"
  ''
)
// {
  meta = {
    inherit description;
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
