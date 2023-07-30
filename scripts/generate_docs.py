import json
import os
from subprocess import check_output, CalledProcessError

ANIXDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ANIXDIR, "pkgIndex.json"), "r") as idxfile:
    pkgs = json.loads(idxfile.read())

miscPkgs = [{"name": pkg["attr"].split(
    ".")[-1], "attr": pkg["attr"]} for pkg in pkgs["pkgs"]["misc"]]
cppPkgs = [{"name": pkg["attr"].split(
    ".")[-1], "attr": pkg["attr"]} for pkg in pkgs["pkgs"]["cpp"]]
pythonPkgs = [{"name": pkg["attr"].split(
    ".")[-1], "attr": pkg["attr"]} for pkg in pkgs["pkgs"]["python"]]

with open(os.path.join(ANIXDIR, "docs", "src", "SUMMARY.md"), "w") as summaryfile, \
        open(os.path.join(ANIXDIR, "docs", "src", "misc", "misc.md"), "w") as miscfile, \
        open(os.path.join(ANIXDIR, "docs", "src", "cpp", "cpp.md"), "w") as cppfile, \
        open(os.path.join(ANIXDIR, "docs", "src", "python", "python.md"), "w") as pythonfile:
    summaryfile.write("# Summary\n\n")
    summaryfile.write("- [anixpkgs Overview](./intro.md)\n")
    summaryfile.write("- [Machine Management](./machines.md)\n")

    summaryfile.write("- [C++ Packages](./cpp/cpp.md)\n")
    cppfile.write("# C++ Packages\n\n")
    cppfile.write(
        "Packages written in C++.\n\n")
    for cppPkg in cppPkgs:
        print(cppPkg["name"])
        pkgMdname = f"{cppPkg['name']}.md"
        summaryfile.write(f"  - [{cppPkg['attr']}](./cpp/{pkgMdname})\n")
        cppfile.write(f"- [{cppPkg['attr']}](./{pkgMdname})\n")
        with open(os.path.join(ANIXDIR, "docs", "src", "cpp", pkgMdname), "w") as pkgfile:
            pkgfile.write(f"# {cppPkg['attr']}\n\n")
            try:
                docf = check_output(
                    ["nix-build", ".", "-A", f"{cppPkg['attr']}.doc", "--no-out-link"])
            except CalledProcessError:
                print(
                    f"ERROR: {cppPkg['attr']} does not appear to have a doc attribute defined.")
                exit(1)
            with open(docf.decode().strip(), "r") as docfile:
                docstr = docfile.read()
                pkgfile.write(docstr)

    summaryfile.write("- [Python Packages](./python/python.md)\n")
    pythonfile.write("# Python Packages\n\n")
    pythonfile.write(
        "Packages written (or bound) in Python.\n\n")
    for pythonPkg in pythonPkgs:
        print(pythonPkg["name"])
        pkgMdname = f"{pythonPkg['name']}.md"
        summaryfile.write(f"  - [{pythonPkg['attr']}](./python/{pkgMdname})\n")
        pythonfile.write(f"- [{pythonPkg['attr']}](./{pkgMdname})\n")
        with open(os.path.join(ANIXDIR, "docs", "src", "python", pkgMdname), "w") as pkgfile:
            pkgfile.write(f"# {pythonPkg['attr']}\n\n")
            try:
                docf = check_output(
                    ["nix-build", ".", "-A", f"{pythonPkg['attr']}.doc", "--no-out-link"])
            except CalledProcessError:
                print(
                    f"ERROR: {pythonPkg['attr']} does not appear to have a doc attribute defined.")
                exit(1)
            with open(docf.decode().strip(), "r") as docfile:
                docstr = docfile.read()
                pkgfile.write(docstr)

    summaryfile.write("- [Miscellaneous Packages](./misc/misc.md)\n")
    miscfile.write("# Miscellaneous Packages\n\n")
    miscfile.write(
        "Packages written in assorted languages like Bash, Rust, Java, etc.\n\n")
    for miscPkg in miscPkgs:
        print(miscPkg["name"])
        pkgMdname = f"{miscPkg['name']}.md"
        summaryfile.write(f"  - [{miscPkg['attr']}](./misc/{pkgMdname})\n")
        miscfile.write(f"- [{miscPkg['attr']}](./{pkgMdname})\n")
        with open(os.path.join(ANIXDIR, "docs", "src", "misc", pkgMdname), "w") as pkgfile:
            pkgfile.write(f"# {miscPkg['attr']}\n\n")
            try:
                docf = check_output(
                    ["nix-build", ".", "-A", f"{miscPkg['attr']}.doc", "--no-out-link"])
            except CalledProcessError:
                print(
                    f"ERROR: {miscPkg['attr']} does not appear to have a doc attribute defined.")
                exit(1)
            with open(docf.decode().strip(), "r") as docfile:
                docstr = docfile.read()
                pkgfile.write(docstr)
