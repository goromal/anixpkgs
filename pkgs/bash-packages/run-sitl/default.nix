{ writeShellScriptBin
, callPackage
, color-prints
}:
let
    cmd-name = "run-sitl-machine";
    usage_str = ''
    usage: ${cmd-name} machine-name

    Run a SITL emulation for <nixpkgs> -A nixos-machines.[machine-name].sitl

    Machines:
        - minimal: Just the latest kernel, and nothing else.
        - base: Machine wrapper around all common processes and programs.
    '';
    argparse = callPackage ../bash-utils/argparse.nix {
        inherit usage_str;
        optsWithVarsAndDefaults = [ ];
    };
    printerr = "${color-prints}/bin/echo_red";
    printusage = ''
    cat << EOF
${usage_str}
EOF
    '';
in writeShellScriptBin cmd-name ''
    ${argparse}
    machine_name=$1
    if [[ -z "$machine_name" ]]; then
        ${printerr} "ERROR: no machine-name specified."
        ${printusage}
        exit
    fi

    out_path=$(nix-build '<nixpkgs>' -A nixos-machines.$machine_name.sitl.driver)
    sudo $out_path/bin/nixos-test-driver
''
