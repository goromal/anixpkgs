import json
import os
from subprocess import check_output, CalledProcessError, DEVNULL

ANIXDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ANIXDIR, "ANIX_VERSION"), "r") as version_file:
    version_tag = version_file.read()

with open(os.path.join(ANIXDIR, "docs", "raw", "README.md"), "r") as raw_readme, \
        open(os.path.join(ANIXDIR, "README.md"), "w") as readme:
    readme_text_raw = raw_readme.read()
    readme.write(readme_text_raw.replace("RELEASETAGREPLACE", version_tag))

with open(os.path.join(ANIXDIR, "docs", "raw", "intro.md"), "r") as raw_intro, \
        open(os.path.join(ANIXDIR, "docs", "src", "intro.md"), "w") as intro:
    intro_text_raw = raw_intro.read()
    intro.write(intro_text_raw.replace("RELEASETAGREPLACE", version_tag))

with open(os.path.join(ANIXDIR, "index.json"), "r") as idxfile:
    pkgs = json.loads(idxfile.read())

miscPkgs = [{"name": pkg["attr"].split(
    ".")[-1], "attr": pkg["attr"]} for pkg in pkgs["pkgs"]["misc"]]
cppPkgs = [{"name": pkg["attr"].split(
    ".")[-1], "attr": pkg["attr"]} for pkg in pkgs["pkgs"]["cpp"]]
pythonPkgs = [{"name": pkg["attr"].split(
    ".")[-1], "attr": pkg["attr"]} for pkg in pkgs["pkgs"]["python"]]

with open(os.path.join(ANIXDIR, "docs", "src", "SUMMARY.md"), "w") as summaryfile, \
        open(os.path.join(ANIXDIR, "docs", "src", "rfcs", "rfcs.md"), "w") as rfcsfile, \
        open(os.path.join(ANIXDIR, "docs", "src", "misc", "misc.md"), "w") as miscfile, \
        open(os.path.join(ANIXDIR, "docs", "src", "cpp", "cpp.md"), "w") as cppfile, \
        open(os.path.join(ANIXDIR, "docs", "src", "python", "python.md"), "w") as pythonfile:
    summaryfile.write("# Summary\n\n")
    summaryfile.write("- [anixpkgs Overview](./intro.md)\n")
    summaryfile.write("- [Machine Management](./machines.md)\n")

    summaryfile.write("- [RFCs](./rfcs/rfcs.md)\n")
    rfcsfile.write("# RFCs\n\n")
    rfcsfile.write("Request For Comments (RFC) documents are convenient for organizing and iterating on designs for pieces of software. " + 
    "They can serve as north stars for the implementation of more complex software. Below are some examples of RFCs that I've used to " +
    "guide some personal projects.\n\n")
    for rfc in pkgs["rfcs"]:
        print(rfc["file"])
        rfcsfile.write(f"- [{rfc['title']}](./{rfc['file']}.md)\n")
        summaryfile.write(f"  - [{rfc['title']}](./rfcs/{rfc['file']}.md)\n")

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
                    ["nix-build", ".", "-A", f"{cppPkg['attr']}.doc", "--no-out-link"], stderr=DEVNULL)
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
                    ["nix-build", ".", "-A", f"{pythonPkg['attr']}.doc", "--no-out-link"], stderr=DEVNULL)
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
                    ["nix-build", ".", "-A", f"{miscPkg['attr']}.doc", "--no-out-link"], stderr=DEVNULL)
            except CalledProcessError:
                print(
                    f"ERROR: {miscPkg['attr']} does not appear to have a doc attribute defined.")
                exit(1)
            with open(docf.decode().strip(), "r") as docfile:
                docstr = docfile.read()
                pkgfile.write(docstr)
