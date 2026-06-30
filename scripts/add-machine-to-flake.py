#!/usr/bin/env python3
"""Add a new machine entry to flake.nix nixosConfigurations.

Usage:
  python3 scripts/add-machine-to-flake.py personal <hardware-name>
  python3 scripts/add-machine-to-flake.py jetpack <variant>

Idempotent: exits 0 without modification if the entry already exists.
Must be run from the repo root (where flake.nix lives).
"""

import sys

PERSONAL_ANCHOR = "        # ATS servers"
JETPACK_ANCHOR = "        # Drone simulation"


def personal_entry(name: str) -> str:
    return (
        f"        atorgesen-{name} = nixpkgs.lib.nixosSystem {{\n"
        f"          system = \"x86_64-linux\";\n"
        f"          specialArgs = commonSpecialArgs;\n"
        f"          modules = commonModules ++ [ ./pkgs/nixos/configurations/personal-{name}.nix ];\n"
        f"        }};\n\n"
    )


def jetpack_entry(variant: str) -> str:
    return (
        f"        jetson-{variant} =\n"
        f"          let\n"
        f"            jetpackNixpkgs = jetpack-nixos.inputs.nixpkgs;\n"
        f"          in\n"
        f"          jetpackNixpkgs.lib.nixosSystem {{\n"
        f"            system = \"aarch64-linux\";\n"
        f"            specialArgs = commonSpecialArgs;\n"
        f"            modules = commonModules ++ [\n"
        f"              jetpack-nixos.nixosModules.default\n"
        f"              ./pkgs/nixos/configurations/jetpack-{variant}.nix\n"
        f"            ];\n"
        f"          }};\n\n"
    )


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} personal|jetpack <name>", file=sys.stderr)
        sys.exit(1)

    kind, name = sys.argv[1], sys.argv[2]

    if kind == "personal":
        attr = f"atorgesen-{name}"
        anchor = PERSONAL_ANCHOR
        entry = personal_entry(name)
    elif kind == "jetpack":
        attr = f"jetson-{name}"
        anchor = JETPACK_ANCHOR
        entry = jetpack_entry(name)
    else:
        print(f"Unknown kind: {kind!r} (expected 'personal' or 'jetpack')", file=sys.stderr)
        sys.exit(1)

    with open("flake.nix") as f:
        content = f.read()

    if f"{attr} =" in content:
        print(f"{attr} already present in flake.nix, skipping.")
        sys.exit(0)

    if anchor not in content:
        print(f"Anchor {anchor!r} not found in flake.nix — has the file structure changed?", file=sys.stderr)
        sys.exit(1)

    with open("flake.nix", "w") as f:
        f.write(content.replace(anchor, entry + anchor, 1))

    print(f"Added {attr} to flake.nix.")


if __name__ == "__main__":
    main()
