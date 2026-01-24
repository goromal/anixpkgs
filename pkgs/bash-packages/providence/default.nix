{ writeArgparseScriptBin, color-prints, wiki-tools, sread }:
let
  pkgname = "providence";
  usage_str = ''
    usage: ${pkgname} [options] domain

    Pick randomly from a specified domain:
    - patriarchal
    - passage
    - talk

    Options:
    --wiki-url URL   URL of wiki to get data from (default: https://notes.andrewtorgesen.com)
  '';
  printErr = "${color-prints}/bin/echo_red";
  wikitools = "${wiki-tools}/bin/wiki-tools";
  wikiuser = "$(cat $HOME/secrets/wiki/u.txt)";
  wikipass = "$(${sread}/bin/sread $HOME/secrets/wiki/p.txt.tyz)";
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
      readarray -t sentences <<< $(${wikitools} --url $wiki_url --wiki-user ${wikiuser} --wiki-pass ${wikipass} get --page-id andrews-blessing | tr '\n' ' ' | sed -e :1 -e 's/\([.?!]\)[[:blank:]]\{1,\}\([^[:blank:]]\)/\1\n\2/;t1')
      echo ''${sentences[ $SRANDOM % ''${#sentences[@]} ]}
  elif [[ "$domain" == "passage" ]]; then
      readarray -t scriplist <<< $(${wikitools} --url $wiki_url --wiki-user ${wikiuser} --wiki-pass ${wikipass} get --page-id backend:scriptural-canon)
      scripdesc=''${scriplist[ $SRANDOM % ''${#scriplist[@]} ]}
      readarray -d '!' -t scriptdat <<< "$scripdesc"
      scripname="''${scriptdat[0]}"
      readarray -d '|' -t bookspecs <<< "''${scriptdat[1]}"
      bookspec=''${bookspecs[ $SRANDOM % ''${#bookspecs[@]} ]}
      readarray -d ':' -t bookdat <<< "$bookspec"
      bookname="''${bookdat[0]}"
      chapsnum="''${bookdat[1]}"
      chap=$(( ( SRANDOM % $chapsnum )  + 1 ))
      echo "''${scripname} -> ''${bookname} $chap"
  elif [[ "$domain" == "talk" ]]; then
      readarray -t talklist <<< $(${wikitools} --url $wiki_url --wiki-user ${wikiuser} --wiki-pass ${wikipass} get --page-id backend:talks)
      talkdesc=''${talklist[ $SRANDOM % ''${#talklist[@]} ]}
      readarray -d '!' -t talkdat <<< "$talkdesc"
      session="''${talkdat[0]}"
      readarray -d '|' -t talknames <<< "''${talkdat[1]}"
      talkname=''${talknames[ $SRANDOM % ''${#talknames[@]} ]}
      echo "''${session} - ''${talkname}"
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
