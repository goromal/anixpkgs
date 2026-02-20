{
  writeArgparseScriptBin,
  color-prints,
  coreutils,
  xorg,
  gawk,
  gnugrep,
}:
let
  pkgname = "getres";
  description = "Get the screen resolution of this computer.";
  usagestr = ''
    usage: ${pkgname} [opts]

    ${description}

    Options:
      -v|--verbose   Print diagnostic information
      --no-fail      Fall back to a reasonable default resolution if this
                     computer's resolution can't be deduced
  '';
  printErr = "${color-prints}/bin/echo_red";
  printYlw = "${color-prints}/bin/echo_yellow";
in
(writeArgparseScriptBin pkgname usagestr
  [
    {
      var = "verbose";
      isBool = true;
      default = "0";
      flags = "-v|--verbose";
    }
    {
      var = "no_fail";
      isBool = true;
      default = "0";
      flags = "--no-fail";
    }
  ]
  ''
    if [[ "$verbose" == 1 ]]; then
      ${printYlw} "Grabbing resolution from xdpyinfo"
    fi
    restry=$(${xorg.xdpyinfo}/bin/xdpyinfo | ${gawk}/bin/awk '/dimensions/{print $2}')
    res=$(${coreutils}/bin/echo "$restry" | ${gnugrep}/bin/grep -Eo "[0-9]+x[0-9]+")
    if [[ -z "$res" ]]; then
      if [[ "$verbose" == 1 ]]; then
        ${printErr} "Failed to grab resolution:"
        ${coreutils}/bin/echo "$restry"
      fi
      if [[ "$no_fail" == 0 ]]; then
        exit 1
      fi
    else
      ${coreutils}/bin/echo $res
      exit
    fi

    if [[ "$verbose" == 1 ]]; then
      ${printYlw} "Falling back to a default resolution"
    fi
    ${coreutils}/bin/echo 1920x1080
  ''
)
// {
  meta = {
    inherit description;
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
