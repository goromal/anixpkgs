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
        pkg_pattern = re.compile(
            r"\s*" + attr + r"\s*=\s*addDoc\s*\(\s*\S*callPackage\s*(\S*)s*"
        )
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
                deps_lines.append(
                    line.replace("{", "")
                    .replace("}", "")
                    .replace(":", "")
                    .replace("\n", "")
                    .replace(",", "")
                    .strip()
                )
            if "}" in line:
                break
    deps = []
    for deps_line in deps_lines:
        linesplit = deps_line.split()
        if len(linesplit) > 1:
            for dep in linesplit:
                deps.append(f'"{dep}"')
        else:
            deps.append(f'"{linesplit[0]}"')
    return deps


def devrc_components_by_ws(devrcfile, wsname, DATADIR=os.path.expanduser("~/data")):
    DEVDIR = os.path.expanduser("~/dev")
    PKGSDIR = os.path.expanduser("~/sources/nixpkgs")
    PKGSVAR = "<nixpkgs>"
    repos = {}
    attrs = {}
    urls = {}
    wsscripts = {}
    dependencies = {}
    wssources = []
    foundws = False
    with open(devrcfile, "r") as devrc:
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
                    repos[left.replace("[", "").replace("]", "")] = right
                elif "<" in left:
                    wsscripts[left.replace("<", "").replace(">", "")] = right
                elif left == wsname:
                    wssources = right.split()
                    foundws = True
    if not foundws:
        return (
            foundws,
            DEVDIR,
            PKGSVAR,
            repos,
            attrs,
            urls,
            wsscripts,
            dependencies,
            wssources,
        )

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

    return (
        foundws,
        DEVDIR,
        PKGSVAR,
        repos,
        attrs,
        urls,
        wsscripts,
        dependencies,
        wssources,
    )


def parse_ws():
    DEVRCFILE = os.path.expanduser(sys.argv[2])
    if not os.path.exists(DEVRCFILE):
        print("_NODEVRC_")
        exit()

    if len(sys.argv) < 4:
        print("_NOWSGIVEN_")
        exit()

    wsname = sys.argv[3]
    if len(sys.argv) > 4:
        DATADIR = os.path.expanduser(sys.argv[4])
    else:
        DATADIR = os.path.expanduser("~/data")

    source_sets = []
    script_sets = []
    sources = "[]"  # "[{name=...;url=...;attr=...;deps=[...];}]"
    scripts = "[]"

    try:
        (
            foundws,
            DEVDIR,
            PKGSVAR,
            repos,
            attrs,
            urls,
            wsscripts,
            dependencies,
            wssources,
        ) = devrc_components_by_ws(DEVRCFILE, wsname, DATADIR)
        if not foundws:
            print("_NOWSFOUND_")
            exit()
        for wssource in wssources:
            if wssource in dependencies:
                deps_str = "[{}]".format(" ".join(dependencies[wssource]))
                source_sets.append(
                    f'{{name="{wssource}";url="{urls[wssource]}";attr="{attrs[wssource]}";deps={deps_str};}}'
                )
            elif wssource in wsscripts:
                script_sets.append(
                    f'"{wssource}={os.path.join(DATADIR, wsscripts[wssource])}"'
                )
        sources = "[{}]".format("".join(source_sets))
        scripts = "[{}]".format(" ".join(script_sets))
    except Exception as e:
        print("ERROR:", e)
        exit()

    print(f"{DEVDIR}|{DATADIR}|{PKGSVAR}|{sources}|{scripts}")


def add_to_ws():
    wsname = sys.argv[2]
    devrc = os.path.expanduser(sys.argv[3])
    reponame = sys.argv[4]
    try:
        repourl = sys.argv[5]
        hasurl = True
    except:
        hasurl = False

    try:
        (
            foundws,
            DEVDIR,
            PKGSVAR,
            repos,
            attrs,
            urls,
            wsscripts,
            dependencies,
            wssources,
        ) = devrc_components_by_ws(devrc, wsname)

        with open(devrc, "r") as devrcfile:
            devrclines = devrcfile.readlines()

        # with open(devrcfile, "r") as devrc:
        # for line in devrc:
        #     if "#" not in line and "=" in line:
        #         left = line.split("=")[0].strip()
        #         right = line.split("=")[1].strip()

        if reponame not in repos:
            if not hasurl:
                print(f"Cannot add {reponame} to source list without a url")
                exit(1)
            print(f"Adding {reponame} to source list")
            def find_last_bracket_index(lst):
                for i in range(len(lst) - 1, -1, -1):
                    if "=" in list[i]:
                        left = line.split("=")[0].strip()
                        if left.startswith('['):
                            return i
                return len(lst)-1
            last_src_idx = find_last_bracked_index(devrclines)
            devrclines.insert(last_src_idx+1, f"[{reponame}] = {repourl}")

            # ^^^^ TODO
        if reponame not in wssources:
            print(f"Adding {reponame} to workspace {wsname}")
            # ^^^^ TODO
        
        # ^^^^ TODO write lines

    except Exception as e:
        print("ERROR:", e)
        exit()


def main():
    cmd = sys.argv[1]
    if cmd == "PARSE":
        parse_ws()
    elif cmd == "ADD":
        add_to_ws()


if __name__ == "__main__":
    main()
