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

langs = [
    ("cpp", "C++ Packages", "Packages written in C++."),
    ("rust", "Rust Packages", "Packages written in Rust."),
    ("python", "Python Packages", "Packages written (or bound) in Python."),
    ("bash", "Bash Packages", "Packages written (or glued together) in Bash."),
    ("java", "Java Packages", "(Toy) Packages written in Java.")
]

summaryfile = open(os.path.join(ANIXDIR, "docs", "src", "SUMMARY.md"), "w")
rfcsfile = open(os.path.join(ANIXDIR, "docs", "src", "rfcs", "rfcs.md"), "w")

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

for lang, title, desc in langs:
    lang_pkgs =  [{"name": pkg["attr"].split(
        ".")[-1], "attr": pkg["attr"]} for pkg in pkgs["pkgs"][lang]]
    with open(os.path.join(ANIXDIR, "docs", "src", lang, f"{lang}.md"), "w") as langfile:
        summaryfile.write(f"- [{title}](./{lang}/{lang}.md)\n")
        langfile.write(f"# {title}\n\n")
        langfile.write(f"{desc}\n\n")
        for lang_pkg in lang_pkgs:
            print(lang_pkg["name"])
            pkgMdname = f"{lang_pkg['name']}.md"
            summaryfile.write(f"  - [{lang_pkg['attr']}](./{lang}/{pkgMdname})\n")
            langfile.write(f"- [{lang_pkg['attr']}](./{pkgMdname})\n")
            with open(os.path.join(ANIXDIR, "docs", "src", lang, pkgMdname), "w") as pkgfile:
                pkgfile.write(f"# {lang_pkg['attr']}\n\n")
                try:
                    docf = check_output(
                        ["nix-build", ".", "-A", f"{lang_pkg['attr']}.doc", "--no-out-link"], stderr=DEVNULL)
                except CalledProcessError:
                    print(
                        f"ERROR: {lang_pkg['attr']} does not appear to have a doc attribute defined.")
                    exit(1)
                with open(docf.decode().strip(), "r") as docfile:
                    docstr = docfile.read()
                    pkgfile.write(docstr)

rfcsfile.close()
summaryfile.close()
