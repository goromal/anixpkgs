import os
import re
import sys

def get_url_from_dep(dep, attr):
    with open(f"{dep}/sources.nix", "r") as sources_file:
        url_pattern = re.compile(r"\s*" + attr + r"\s*=\s*builtins.fetchGit\s*\{\s*\n\s*url\s*=\s*\"(.+)\";", re.MULTILINE)
        url_search = url_pattern.search(sources_file.read())
    if not url_search:
        raise Exception
    return url_search.group(1)

def get_deps_from_dep(dep, attr):
    with open(f"{dep}/pkgs/default.nix", "r") as pkgs_file:
        pkg_pattern = re.compile(r"\s*" + attr + r"\s*=\s*\S*callPackage\s*(\S*)s*")
        pkg_search = pkg_pattern.search(pkgs_file.read())
    if not pkg_search:
        raise Exception
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
    DEVDIR = "~/dev"
    DATADIR = "~/data"
    DEVRCFILE = os.path.expanduser("~/.devrc")
    # DEVRCFILE = "devrc_ex"

    if not os.path.exists(DEVRCFILE):
        print("_NODEVRC_")
        exit()

    if len(sys.argv) < 2:
        print("_NOWSGIVEN_")
        exit()

    wsname = sys.argv[1]
    deployments = {}
    repos = {}
    urls = {}
    dependencies = {}
    wssources = []
    source_sets = []
    sources = "[]" # "[{name=...;url=...;deps=[...];}]"
    foundws = False

    try:
        with open(DEVRCFILE, "r") as devrc:
            for line in devrc:
                if "#" not in line and "=" in line:
                    left = line.split("=")[0].strip()
                    right = line.split("=")[1].strip()
                    if left == "dev_dir":
                        DEVDIR = right
                    elif left == "data_dir":
                        DATADIR = right
                    elif "<" in left:
                        deployments[left.replace("<","").replace(">","")] = os.path.expanduser(right)
                    elif "[" in left:
                        repos[left.replace("[","").replace("]","")] = right
                    elif left == wsname:
                        wssources = right.split()
                        foundws = True
            if not foundws:
                print("_NOWSFOUND_")
                exit()
            
        for repo, spec in repos.items():
            specsplit = spec.split()
            if len(specsplit) > 1:
                deployment = specsplit[0]
                attr = specsplit[1]
                dep = deployments[deployment]
                urls[repo] = get_url_from_dep(dep, attr)
                dependencies[repo] = get_deps_from_dep(dep, attr)
            else:
                urls[repo] = specsplit[0]
                dependencies[repo] = []
        
        for wssource in wssources:
            deps_str = "[{}]".format(" ".join(dependencies[wssource]))
            source_sets.append(f"{{name=\"{wssource}\";url=\"{urls[wssource]}\";deps={deps_str};}}")
        
        sources = "[{}]".format("".join(source_sets))

    except Exception:
        print("_BADDEVRC_")
        exit()

    print(f"{DEVDIR}|{DATADIR}|{sources}")

if __name__ == "__main__":
    main()