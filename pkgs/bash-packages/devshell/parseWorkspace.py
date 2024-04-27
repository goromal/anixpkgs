import json
import os
import re
import sys

def get_url_from_dep(dep, attr):
    with open(f"{dep}/flake.lock", "r") as lock_file:
        lock = json.loads(lock_file.read())
    if attr not in lock["nodes"] or "original" not in lock["nodes"][attr]:
        raise Exception(f"Attribute {attr} not found in lockfile")
    original = lock["nodes"][attr]["original"]
    if "type" in original and original["type"] == "github":
        return f"https://github.com/{original['owner']}/{original['repo']}"
    elif "url" in original:
        return original["url"]
    else:
        raise Exception(f"Unknown source type for attribute {attr}")

def get_deps_from_dep(dep, attr):
    with open(f"{dep}/pkgs/default.nix", "r") as pkgs_file:
        pkg_pattern = re.compile(r"\s*" + attr + r"\s*=\s*addDoc\s*\(\s*\S*callPackage\s*(\S*)s*")
        pkg_search = pkg_pattern.search(pkgs_file.read())
    if not pkg_search:
        raise Exception(f"Unable to locate derivation for attribute {attr}")
    pkg_rel_path = pkg_search.group(1)
    if ".nix" not in pkg_rel_path:
        pkg_rel_path += "/default.nix"
    pkg_path = os.path.join(dep, "pkgs", pkg_rel_path)
    deps_lines = []
    with open(pkg_path, "r") as pkg_file:
        for line in pkg_file:
            if "{" in line or "," in line:
                deps_lines.append(line.replace("{","").replace("}","").replace(":","").replace("\n","").replace(",","").strip())
            if "}" in line:
                break
    deps = []
    for deps_line in deps_lines:
        linesplit = deps_line.split()
        if len(linesplit) > 1:
            for dep in linesplit:
                deps.append(f"\"{dep}\"")
        else:
            deps.append(f"\"{linesplit[0]}\"")
    return deps

def main():
    DEVDIR = os.path.expanduser("~/dev")
    DATADIR = os.path.expanduser("~/data")
    PKGSDIR = os.path.expanduser("~/sources/nixpkgs")
    PKGSVAR = "<nixpkgs>"
    DEVRCFILE = os.path.expanduser(sys.argv[1])
    # DEVRCFILE = "devrc_ex"

    if not os.path.exists(DEVRCFILE):
        print("_NODEVRC_")
        exit()

    if len(sys.argv) < 3:
        print("_NOWSGIVEN_")
        exit()

    wsname = sys.argv[2]
    repos = {}
    attrs = {}
    urls = {}
    wsscripts = {}
    dependencies = {}
    wssources = []
    source_sets = []
    script_sets = []
    sources = "[]" # "[{name=...;url=...;attr=...;deps=[...];}]"
    scripts = "[]"
    foundws = False

    try:
        with open(DEVRCFILE, "r") as devrc:
            for line in devrc:
                if "#" not in line and "=" in line:
                    left = line.split("=")[0].strip()
                    right = line.split("=")[1].strip()
                    if left == "dev_dir":
                        DEVDIR = os.path.expanduser(right)
                    elif left == "data_dir":
                        DATADIR = os.path.expanduser(right)
                    elif left == "pkgs_dir":
                        PKGSDIR = os.path.expanduser(right)
                    elif left == "pkgs_var":
                        PKGSVAR = right
                    elif "[" in left:
                        repos[left.replace("[","").replace("]","")] = right
                    elif "<" in left:
                        wsscripts[left.replace("<","").replace(">","")] = right
                    elif left == wsname:
                        wssources = right.split()
                        foundws = True
            if not foundws:
                print("_NOWSFOUND_")
                exit()

        if len(sys.argv) > 3:
            DATADIR = os.path.expanduser(sys.argv[3])

        for repo, spec in repos.items():
            specsplit = spec.split()
            if len(specsplit) > 1:
                attr = specsplit[1]
                dep = PKGSDIR
                attrs[repo] = f"pkgs.{attr}"
                urls[repo] = get_url_from_dep(dep, attr.split(".")[-1])
                dependencies[repo] = get_deps_from_dep(dep, attr.split(".")[-1])
            else:
                attrs[repo] = ""
                urls[repo] = specsplit[0]
                dependencies[repo] = []
        
        for wssource in wssources:
            if wssource in dependencies:
                deps_str = "[{}]".format(" ".join(dependencies[wssource]))
                source_sets.append(f"{{name=\"{wssource}\";url=\"{urls[wssource]}\";attr=\"{attrs[wssource]}\";deps={deps_str};}}")
            elif wssource in wsscripts:
                script_sets.append(f"\"{wssource}={os.path.join(DATADIR, wsscripts[wssource])}\"")
        
        sources = "[{}]".format("".join(source_sets))
        scripts = "[{}]".format(" ".join(script_sets))

    except Exception as e:
        print("ERROR:", e)
        exit()

    print(f"{DEVDIR}|{DATADIR}|{PKGSVAR}|{sources}|{scripts}")

if __name__ == "__main__":
    main()
