# cpp-helper

Convenience tools for setting up C++ projects.


## Usage

```bash
usage: cpp-helper [options]

Options:
    exec-lib   CPPNAME      Generate a lib+exec package template
    header-lib CPPNAME      Generate a header-only library template
    format-file             Dumps a format rules file into .clang-format

    nix                     Dump template shell.nix file
    vscode                  Generate VSCode C++ header detection settings file
    make       TARGET|all   Full CMake build command (run from repo root)
    challenge  TARGET|all   Full CMake build command WITH SANITIZERS
                            (run from repo root)

```

