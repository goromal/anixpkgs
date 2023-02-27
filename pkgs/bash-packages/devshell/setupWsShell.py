# Should fail gracefully! Should not interrupt devshell init process
import os, sys

npkgs = len(sys.argv) - 3
DEVDIR = sys.argv[1]
PKGVAR = sys.argv[2]
pkgs = {}
for i in range(3, 3 + npkgs):
    pkgspec = sys.argv[i]
    pkgspecsplit = pkgspec.split(":")
    if pkgspecsplit[1] and "pkg-src" in pkgspecsplit[2:]:
        pkgs[pkgspecsplit[0]] = (pkgspecsplit[1], pkgspecsplit[2:])

if len(pkgs.keys()) == 0:
    exit()

letset = ""
pyinputset = ""
inputset = ""
for pkgname, pkgspec in pkgs.items():
    if "python3" in pkgspec[0]:
        pyinputset += f"\n      {pkgname}"
    else:
        inputset += f"\n    {pkgname}"
    letset += f"\n  {pkgname} = {pkgspec[0]}.override {{"
    letset += f"\n    pkg-src = pkgs.lib.cleanSource ./sources/{pkgname}/.;"
    for dependency in pkgspec[1]:
        if dependency in pkgs.keys():
            letset += f"\n    inherit {dependency};"
    letset += "\n  };"

shell_contents = """
{{ pkgs ? import {0} {{}}}}:
let{1}
in pkgs.mkShell {{
  nativeBuildInputs = [
    (pkgs.python3.withPackages (p: with p; [
      # other python pkgs here{2}
    ])){3}
    pkgs.bashInteractive
  ];
}}
""".format(PKGVAR, letset, pyinputset, inputset)

with open(os.path.join(DEVDIR, "shell.nix"), "w") as shellfile:
    shellfile.write(shell_contents)
