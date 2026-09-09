{
  lib,
  writeArgparseScriptBin,
  color-prints,
  coreutils,
  strings,
  name,
  extension,
  usage_str,
  optsWithVarsAndDefaults,
  convOptCmds,
  description ? "",
  longDescription ? "",
  autoGenUsageCmd ? "--help",
  # Dispatch vacuum's conversions as orchestrator jobs instead of running them
  # inline. Each file becomes a bash job re-invoking this very converter, so
  # every option the converter accepts applies to the dispatched work.
  vacuumViaOrchestrator ? true,
  # Queue a dependent orchestrator job that deletes each source file. The
  # daemon cancels jobs whose blocker errored, so a source outlives a failed
  # conversion.
  vacuumRemoveSources ? true,
  # Option variables never forwarded to dispatched jobs. Verbosity is excluded
  # by default because the daemon treats any output on stderr as job failure:
  # a verbose conversion would succeed, then be recorded as an error, and its
  # source would survive on a job that did its work.
  vacuumUnforwardedVars ? [ "verbose" ],
}:
let
  conv_opt_list = map (x: ''
    ${x.extension})
    echo "$infile -> $outfile ..."
    ${x.commands}
    ;;
  '') convOptCmds;
  conv_opt_cmds = builtins.concatStringsSep "\n" conv_opt_list;
  printerr = ">&2 ${color-prints}/bin/echo_red";
  printwarn = "${color-prints}/bin/echo_yellow";
  printusage = ''
        cat << EOF
    ${full_usage_str}
    EOF
  '';

  # Spelled out rather than inlined so that the bash below can reference shell
  # variables without colliding with Nix's own ${} interpolation.
  d = "$";

  # Input extensions that `vacuum` can discover on disk. The `random`
  # pseudo-extension is synthesized from a filename spec rather than read off a
  # real file, so it is excluded.
  isRandomToken =
    e:
    builtins.elem (lib.toLower e) [
      "random"
      "rand"
    ];
  inputExtTokens = lib.concatMap (x: lib.splitString "|" x.extension) convOptCmds;
  vacuumExts = lib.unique (map lib.toLower (lib.filter (e: !isRandomToken e) inputExtTokens));
  inameArgs = lib.concatStringsSep " -o " (map (e: ''-iname "*.${e}"'') vacuumExts);

  # Options injected into every orchestrator-backed converter. Deliberately
  # long-form: short flags would collide with converter-specific options.
  orchestratorOpts = [
    {
      var = "orch_port";
      isBool = false;
      default = "";
      flags = "--orch-port";
    }
    {
      var = "orch_priority";
      isBool = false;
      default = "";
      flags = "--orch-priority";
    }
  ];
  allOpts = optsWithVarsAndDefaults ++ lib.optionals vacuumViaOrchestrator orchestratorOpts;

  full_usage_str =
    usage_str
    # No backticks or $ here: usage is printed through an unquoted heredoc, so
    # either would be evaluated by the shell instead of shown.
    + lib.optionalString vacuumViaOrchestrator ''

      Vacuum sweeps files already in .${extension} form only when an option
      above (other than verbosity) asks for a different conversion; those are
      re-encoded in place. Otherwise they are skipped as a no-op.

      Vacuum options (vacuum requires orchestrator on PATH):
               --orch-port PORT        Orchestrator daemon port
               --orch-priority INT     Priority for dispatched jobs
    '';

  # Rebuild the caller's own options as an argv array, so the dispatched job
  # re-invokes this converter exactly as it was invoked. An option is forwarded
  # only when it differs from its default, which keeps the command legible and
  # makes a non-empty default (e.g. a font size) behave the same either way.
  #
  # Options named in vacuumUnforwardedVars are dropped instead, with a warning
  # so the difference is never silent.
  forwardOpt =
    x:
    let
      flag = builtins.head (lib.splitString "|" x.flags);
      val = if x.isBool then "" else " \"${d}${x.var}\"";
      changed = "[[ \"${d}${x.var}\" != \"${x.default}\" ]]";
    in
    if builtins.elem x.var vacuumUnforwardedVars then
      "    if ${changed}; then ${printwarn} \"${flag} does not apply to vacuum; ignoring it.\"; fi\n"
    else
      "    if ${changed}; then conv_opts+=( \"${flag}\"${val} ); fi\n";
  forwardOpts = lib.concatStrings (map forwardOpt optsWithVarsAndDefaults);

  # Preflight for the orchestrator path: refuse to run rather than silently
  # degrade, then assemble everything that is constant across files.
  vacuumSetup = ''
    if ! command -v orchestrator > /dev/null 2>&1; then
        ${printerr} "ERROR: orchestrator not found on PATH."
        ${printerr} "The vacuum sub-command dispatches orchestrator jobs and cannot run without it."
        exit 1
    fi

    # Resolve to this exact build so the dispatched job cannot pick up a
    # different ${name} from the daemon's PATH.
    self="$(readlink -f "$0")"

    # Dispatched jobs run in the daemon's working directory, not this shell's,
    # so every path handed to them has to be absolute. Resolving the input
    # directory here makes find emit absolute paths for both source and output.
    indir="$(readlink -f "$indir")"

    # Orchestrator execs job argv directly and splits the command with shlex,
    # so each word is single-quoted here to survive whitespace and quotes.
    shquote() {
        printf "'%s'" "''${1//\'/\'\\\'\'}"
    }

    conv_opts=()
    ${forwardOpts}
    orch_args=()
    if [[ ! -z "$orch_port" ]]; then orch_args+=( "-p" "$orch_port" ); fi
    job_args=()
    if [[ ! -z "$orch_priority" ]]; then job_args+=( "--priority" "$orch_priority" ); fi

    # Files already in the output format are swept only when an option was given
    # that changes the conversion -- re-encoding them is the whole point then.
    # With no such option the conversion would be a no-op, so they are skipped.
    # Verbosity is not forwarded and so never lands in conv_opts, which is
    # exactly the "besides verbosity" part of that rule.
    #
    # Expressed as a find predicate rather than by dropping the extension from
    # the match list, so it also covers converters that match "*".
    same_ext_filter=()
    if [[ ''${#conv_opts[@]} -eq 0 ]]; then
        same_ext_filter=( ! -iname "*.${extension}" )
    fi
  '';

  # Removal of the source, for the ordinary case where output and source are
  # distinct paths. Blocked on the conversion, so an error cancels it.
  vacuumRemoveStep = lib.optionalString vacuumRemoveSources ''
        rmjob=$(orchestrator "''${orch_args[@]}" remove "''${job_args[@]}" "$f" -b "$convjob")
            if [[ ! "$rmjob" =~ ^[0-9]+$ ]]; then
                ${printerr} "ERROR: could not kick off removal job for $f: $rmjob"
                exit 1
            fi
            note=", remove job $rmjob"
  '';

  # The orchestrator CLI reports a missing daemon on stdout and still exits 0,
  # so a captured job id has to be validated rather than trusted.
  vacuumDispatch = ''
    # A source already in the output format converts onto its own path. Writing
        # a file while reading it would destroy it, so the work goes to a
        # sibling temporary and is moved over the original once it succeeds --
        # and no removal job is queued, since the move consumes the source.
        if [[ "$outfile" == "$f" ]]; then
            target="''${f%.*}.vacuum-tmp.${extension}"
            in_place=1
        else
            target="$outfile"
            in_place=0
        fi

        cmdstr="$(shquote "$self")"
        for a in "''${conv_opts[@]}" "$f" "$target"; do
            cmdstr="$cmdstr $(shquote "$a")"
        done
        convjob=$(orchestrator "''${orch_args[@]}" bash "''${job_args[@]}" "$cmdstr")
        if [[ ! "$convjob" =~ ^[0-9]+$ ]]; then
            ${printerr} "ERROR: could not kick off conversion job for $f: $convjob"
            exit 1
        fi

        note=""
        if [[ "$in_place" == "1" ]]; then
            movecmd="$(shquote "${coreutils}/bin/mv") $(shquote "$target") $(shquote "$f")"
            movejob=$(orchestrator "''${orch_args[@]}" bash "''${job_args[@]}" "$movecmd" -b "$convjob")
            if [[ ! "$movejob" =~ ^[0-9]+$ ]]; then
                ${printerr} "ERROR: could not kick off in-place move job for $f: $movejob"
                exit 1
            fi
            echo "$f (in place) -> convert job $convjob, move job $movejob"
        else
            ${vacuumRemoveStep}
            echo "$f -> $outfile (convert job $convjob''${note})"
        fi
  '';
in
(writeArgparseScriptBin name full_usage_str allOpts ''
  convert_one() {
      infile="$1"
      outfile="$2"
      infile_ext=`${strings.getExtension} "$infile"`
      case $infile_ext in
      ${conv_opt_cmds}
      *)
      ${printerr} "ERROR: unhandled input extension ($infile_ext)."
      ${printusage}
      exit 1
      ;;
      esac
      # A converter that claims success must have produced its output. Several
      # conversions end in cleanup that masks the real exit status, and some
      # suppress stderr entirely, so the output file is the one dependable
      # signal -- and vacuum deletes sources based on it.
      if [[ ! -s "$outfile" ]]; then
          ${printerr} "ERROR: conversion of $infile produced no output ($outfile)."
          return 1
      fi
  }

  if [[ "$1" == "vacuum" ]]; then
      indir="$2"
      if [[ -z "$indir" ]]; then
          ${printerr} "ERROR: no input directory specified."
          ${printusage}
          exit 1
      fi
      if [[ ! -d "$indir" ]]; then
          ${printerr} "ERROR: not a directory ($indir)."
          exit 1
      fi
      ${lib.optionalString vacuumViaOrchestrator vacuumSetup}
      found=0
      while IFS= read -r -d "" f; do
          found=1
          outfile=`${strings.replaceExtension} "$f" ${extension}`
          ${if vacuumViaOrchestrator then vacuumDispatch else ''convert_one "$f" "$outfile"''}
      done < <(find "$indir" -maxdepth 1 -type f \( ${inameArgs} \) ${
        lib.optionalString vacuumViaOrchestrator ''"''${same_ext_filter[@]}"''
      } -print0 | sort -z)
      if [[ "$found" == "0" ]]; then
          ${printwarn} "No files with supported extensions found in $indir."
      fi
      exit 0
  fi

  infile="$1"
  if [[ -z "$infile" ]]; then
      ${printerr} "ERROR: no input file specified."
      ${printusage}
      exit 1
  fi
  if [[ -z "$2" ]]; then
      ${printerr} "ERROR: no output file specified."
      ${printusage}
      exit 1
  fi
  outfile=`${strings.replaceExtension} "$2" ${extension}`
  convert_one "$infile" "$outfile"
'')
// {
  meta = { inherit description longDescription autoGenUsageCmd; };
}
