# anixpkgs

![example workflow](https://github.com/goromal/anixpkgs/actions/workflows/test.yml/badge.svg) [![Deploy](https://github.com/goromal/anixpkgs/actions/workflows/deploy.yml/badge.svg?event=push)](https://github.com/goromal/anixpkgs/actions/workflows/deploy.yml) [![pages-build-deployment](https://github.com/goromal/anixpkgs/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/goromal/anixpkgs/actions/workflows/pages/pages-build-deployment)

![](https://raw.githubusercontent.com/goromal/anixdata/master/data/img/anixpkgs.png "anixpkgs")

**LATEST RELEASE: [v5.11.1](https://github.com/goromal/anixpkgs/tree/v5.11.1)**

**[Repository](https://github.com/goromal/anixpkgs)**

This repository of personally maintained Nix derivations, overlays, and machine closures is essentially the centralized mechanism by which I maintain all of the software I write and use for both personal projects and recreation. In other words, I employ [Nix](https://nixos.org) as both a package manager for my software as well as an operating system for all of my computers, Raspberry Pi’s, etc.

These docs provide an overview of how I manage the OS’s of my [machines](./machines.md) as well as the software that I personally maintain, all within the [anixpkgs](https://github.com/goromal/anixpkgs) repo.

## Why Nix?

Some of the main reasons why I prefer Nix as a package manager:

- I highly value code that is not only compelling in its application but that is also **maintainable**. Code that is subject to compiler/interpreter and external dependency changes over time must be designed with the future in mind. Nix provides me an almost trivial mechanism to incrementally update (and roll back) external dependencies, compilers, or anything else pertaining to a software ecosystem that you can think of.
- When I write a cool piece of software on one machine, I want to be able to “deploy” that software across all my machines with minimal effort and without having to worry about broken or missing dependencies. With its hermetic build system, I have the peace of mind that the code that I package in Nix will be **transferable** to essentially any other machine that uses Nix.

Some of the main reasons why I prefer NixOS as an operating system for all of my computers:

- The same things I value in packaging software, I also value in “packaging an operating system.” NixOS allows me to have **total control** over every single package in my OS, allowing me to customize every aspect and make changes with the peace of mind that I can always roll back breaking changes.
- There is something very satisfying and empowering to me about being able to **declaratively define the OS closures for all of my machines in just several text files.** The overlay-focused design of NixOS modules makes it so that I can design the OS’s of my machines hierarchically, defining packages that are shared between *all* of my computers as well as packages that are specific to certain computers only. Moreover, when I buy a replacement computer it takes a minimal amount of steps to turn that new computer into an *all-intents-and-purposes clone* of my old one, which is a capability I value very highly for a lot of reasons.

Given the above, why do I prefer Nix over Docker?

- To be clear, I do think that Nix and Docker can be used together effectively. However:
- In general, one will require a mishmash of custom or third-party build and deployment tooling to construct and glue a bunch of Docker containers together if one is trying to architect a complete *system* using Docker (as could be the case with code running on a robot). Nix provides more of a unified framework to achieve the same benefits, and that ecosystem is much more aesthetically pleasing to me than e.g., "[YAML engineering](https://media.ccc.de/v/nixcon-2023-35290-nix-and-kubernetes-deployments-done-right#t=2)."
- Docker containers sit atop an already existing, fully fleshed out operating system. Nix allows me to (once agin, within a unified framework) control literally everything about even the operating system in an attempt to avoid unintended side effects at all levels of integration.

## Installation and Usage Patterns

The packages defined in this repo are accessible to anyone who uses [Nix](https://nixos.org), which can be [installed](https://nixos.org/download.html) in two forms:

- **“Standalone” Nix:** This will just install the package manager and is the easiest option if you just want access to the packages in this repo. This option could be augmented with a tool called [home-manager](https://nix-community.github.io/home-manager/) to at least be able to use *some* of the closure components alongside your normal OS as well.
- **NixOS:** This option is much more invasive as it wholesale replaces your entire operating system, and should only be done if you really know what you’re doing (and love Nix). More instructions in the [machines](./machines.md) documentation.

For either method, ensure that your Nix version is `>= 2.4`.

The software packaged in `anixpkgs` is buildable both through [Nix flakes](https://nixos.wiki/wiki/Flakes) as well as through traditional Nix shells. It’s recommended to use flakes, as that method is more "pure" and allows for more portable integration with the public cache.

### Accessing the Packages Using Flakes

Here is a `flake.nix` file that will get you a shell with select `anixpkgs` software (version `v5.11.1`) while also giving you access to the public cache to avoid building from source on your machine:

```nix
{
  description = "Nix shell for anixpkgs.";
  nixConfig.substituters = [
    "https://cache.nixos.org/"
    "https://github-public.cachix.org"
  ];
  nixConfig.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "github-public.cachix.org-1:xofQDaQZRkCqt+4FMyXS5D6RNenGcWwnpAXRXJ2Y5kc="
  ];
  inputs = {
    nixpkgs.url = "github:goromal/anixpkgs?ref=refs/tags/v5.11.1";
  };
  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in with pkgs; {
      devShell.x86_64-linux = mkShell {
        buildInputs = [
          pb
          fixfname
          pkgshell
        ];
      };
    };
}
```

Access the packages with `nix develop`.

### Accessing the Packages Using shell.nix

Here are some `shell.nix` files to access Python packages (using version `v5.11.1` of the packages):

```nix
let
  pkgs = import (builtins.fetchTarball
    "https://github.com/goromal/anixpkgs/archive/refs/tags/v5.11.1.tar.gz") {};
  python-with-my-packages = pkgs.python39.withPackages (p: with p; [
    numpy
    matplotlib
    geometry
    pyceres
  ]);
in
python-with-my-packages.env
```

or:

```nix
let
  pkgs = import (builtins.fetchTarball
    "https://github.com/goromal/anixpkgs/archive/refs/tags/v5.11.1.tar.gz") {};
in pkgs.mkShell {
  buildInputs = [
    pkgs.python39
    pkgs.python39.pkgs.numpy
    pkgs.python39.pkgs.geometry
    pkgs.python39.pkgs.find_rotational_conventions
  ];
  shellHook = ''
    # Tells pip to put packages into $PIP_PREFIX instead of the usual locations.
    # See https://pip.pypa.io/en/stable/user_guide/#environment-variables.
    export PIP_PREFIX=$(pwd)/_build/pip_packages
    export PYTHONPATH="$PIP_PREFIX/${pkgs.python39.sitePackages}:$PYTHONPATH"
    export PATH="$PIP_PREFIX/bin:$PATH"
    unset SOURCE_DATE_EPOCH
  '';
}
```

And for general software packages:

```nix
let
  pkgs = import (builtins.fetchTarball
    "https://github.com/goromal/anixpkgs/archive/refs/tags/v5.11.1.tar.gz") {};
in with pkgs; mkShell {
  buildInputs = [
    pb
    fixfname
    pkgshell
  ];
}
```

Access the packages with `nix-shell`.
