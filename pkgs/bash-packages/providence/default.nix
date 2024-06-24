{ writeArgparseScriptBin, color-prints, wiki-tools }:
let
  pkgname = "providence";
  usage_str = ''
    usage: ${pkgname} [options] domain

    Pick randomly from a specified domain:
    - patriarchal
    - passage

    Options:
    --wiki-url URL   URL of wiki to get data from (default: https://notes.andrewtorgesen.com)
  '';
  printErr = "${color-prints}/bin/echo_red";
  wikitools = "${wiki-tools}/bin/wiki-tools";
in (writeArgparseScriptBin pkgname usage_str [{
  var = "wiki_url";
  isBool = false;
  default = "https://notes.andrewtorgesen.com";
  flags = "--wiki-url";
}] ''
  if [[ -z "$1" ]]; then
      ${printErr} "No domain chosen."
      exit 1
  fi
  domain="$1"
  if [[ "$domain" == "patriarchal" ]]; then
      readarray -t sentences <<< $(${wikitools} --url $wiki_url get --page-id andrews-blessing | tr '\n' ' ' | sed -e :1 -e 's/\([.?!]\)[[:blank:]]\{1,\}\([^[:blank:]]\)/\1\n\2/;t1')
      RANDOM=$$$(date +%s)
      echo ''${sentences[ $RANDOM % ''${#sentences[@]} ]}
  elif [[ "$domain" == "passage" ]]; then
      readarray -t scriplist <<< $(${wikitools} --url $wiki_url get --page-id backend:scriptural-canon)
      scripdesc=''${scriplist[ $RANDOM % ''${#scriplist[@]} ]}
      readarray -d '!' -t scriptdat <<< "$scripdesc"
      scripname="''${scriptdat[0]}"
      readarray -d '|' -t bookspecs <<< "''${scriptdat[1]}"
      bookspec=''${bookspecs[ $RANDOM % ''${#bookspecs[@]} ]}
      readarray -d ':' -t bookdat <<< "$bookspec"
      bookname="''${bookdat[0]}"
      chapsnum="''${bookdat[1]}"
      chap=$(( ( RANDOM % $chapsnum )  + 1 ))
      echo "''${scripname} -> ''${bookname} $chap"
  else
      ${printErr} "Unrecognized domain: $domain."
      exit 1
  fi
'') // {
  meta = {
    description = "Be randomly dictated to from passages of importance.";
    longDescription = ''
      Requires a wiki secrets file at `~/secrets/wiki/secrets.json`.
    '';
    autoGenUsageCmd = "--help";
  };
}
