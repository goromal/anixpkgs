---
name: anixpkgs-packages
description: Use when adding new packages to anixpkgs. Covers index.json requirements and ci/docs flag conventions.
---

When adding a new package to anixpkgs:

1. Create the package definition under the appropriate directory (e.g. `pkgs/by-name/`, `pkgs/python-packages/`, etc.).
2. **Create an entry in `index.json`** at the repo root — this is required for CI and documentation generation.
   - Set `"ci": true` for virtually all packages, so the package must build successfully for CI to pass.
   - Set `"docs": true` **only** for custom packages (ones authored in this repo). Third-party packages being wrapped or included should have `"docs": false`.
3. Follow the anixpkgs-deploy workflow: `git add` the new files before running `anix-upgrade`.
