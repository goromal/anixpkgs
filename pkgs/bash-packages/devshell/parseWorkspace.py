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

    rpspec_sets = []
    source_sets = []
    script_sets = []

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
                rpspec_sets.append(f"{wssource}:{attrs[wssource]}:{':'.join(dependencies[wssource])}")
                source_sets.append(f"{wssource}:{urls[wssource]}")
            elif wssource in wsscripts:
                script_sets.append(
                    f'{wssource}={os.path.join(DATADIR, wsscripts[wssource])}'
                )
        rpspecs = " ".join(rpspec_sets)
        sources = " ".join(source_sets)
        scripts = " ".join(script_sets)
    except Exception as e:
        print("ERROR:", e)
        exit()

    print(f"{DEVDIR}|{DATADIR}|{PKGSVAR}|{rpspecs}|{sources}|{scripts}")


def add_src_to_ws():
    wsname = sys.argv[2]
    devrc = os.path.expanduser(sys.argv[3])
    reponame = sys.argv[4]
    try:
        repourl = sys.argv[5]
        hasurl = repourl != ""
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

        if reponame not in repos:
            if not hasurl:
                print(f"Cannot add {reponame} to source list without a url")
                exit(1)
            print(f"Adding {reponame} to source list")
            def find_last_bracket_index(lst):
                for i in range(len(lst) - 1, -1, -1):
                    if "#" not in lst[i] and "=" in lst[i]:
                        left = lst[i].split("=")[0].strip()
                        if left.startswith('['):
                            return i
                return len(lst)-1
            last_src_idx = find_last_bracket_index(devrclines)
            devrclines.insert(last_src_idx+1, f"[{reponame}] = {repourl}\n")

        if reponame not in wssources:
            print(f"Adding {reponame} to workspace {wsname}")
            added_to_ws = False
            for i, line in enumerate(devrclines):
                if "#" not in line and "=" in line:
                    left = line.split("=")[0].strip()
                    if left == wsname:
                        devrclines[i] = line[:-1] + f" {reponame}" + line[-1] if line[-1] == "\n" else line + f" {reponame}"
                        added_to_ws = True
                        break
            if not added_to_ws:
                print(f"Unable to add {reponame} to workspace {wsname}")
                exit(1)

        with open(devrc, "w") as devrcfile:
            for line in devrclines:
                devrcfile.write(line)

    except Exception as e:
        print("ERROR:", e)
        exit(1)

def add_scr_to_ws():
    wsname = sys.argv[2]
    devrc = os.path.expanduser(sys.argv[3])
    scriptname = sys.argv[4]
    try:
        scriptpath = sys.argv[5]
        haspath = scriptpath != ""
    except:
        haspath = False

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

        if scriptname not in wsscripts:
            if not haspath:
                print(f"Cannot add {scriptname} to script list without a path")
                exit(1)
            print(f"Adding {scriptname} to script list")
            def find_last_bracket_index(lst):
                for i in range(len(lst) - 1, -1, -1):
                    if "#" not in lst[i] and "=" in lst[i]:
                        left = lst[i].split("=")[0].strip()
                        if left.startswith('<'):
                            return i
                return len(lst)-1
            last_src_idx = find_last_bracket_index(devrclines)
            devrclines.insert(last_src_idx+1, f"<{scriptname}> = {scriptpath}\n")

        if scriptname not in wssources:
            print(f"Adding {scriptname} to workspace {wsname}")
            added_to_ws = False
            for i, line in enumerate(devrclines):
                if "#" not in line and "=" in line:
                    left = line.split("=")[0].strip()
                    if left == wsname:
                        devrclines[i] = line[:-1] + f" {scriptname}" + line[-1] if line[-1] == "\n" else line + f" {scriptname}"
                        added_to_ws = True
                        break
            if not added_to_ws:
                print(f"Unable to add {scriptname} to workspace {wsname}")
                exit(1)

        with open(devrc, "w") as devrcfile:
            for line in devrclines:
                devrcfile.write(line)

    except Exception as e:
        print("ERROR:", e)
        exit(1)


def add_ws():
    devrc = os.path.expanduser(sys.argv[2])
    wsname = sys.argv[3]

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
        
        if not foundws:
            print(f"Adding workspace {wsname}")

            with open(devrc, "r") as devrcfile:
                devrclines = devrcfile.readlines()
            with open(devrc, "w") as devrcfile:
                for i, line in enumerate(devrclines):
                    if i != len(devrclines) - 1 or line[-1] == "\n":
                        devrcfile.write(line)
                    else:
                        devrcfile.write(line + "\n")
                devrcfile.write(f"{wsname} = \n")
    
    except Exception as e:
        print("ERROR:", e)
        exit(1)


def main():
    cmd = sys.argv[1]
    if cmd == "PARSE":
        parse_ws()
    elif cmd == "ADDSRC":
        add_src_to_ws()
    elif cmd == "ADDSCR":
        add_scr_to_ws()
    elif cmd == "ADDWS":
        add_ws()


if __name__ == "__main__":
    main()
