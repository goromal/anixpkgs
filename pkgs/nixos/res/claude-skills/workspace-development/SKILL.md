---
name: workspace-development
description: Coordinate coding work in an anix devshell workspace, especially cross-repository changes involving anixpkgs, flasks, anixdata, Nix flake inputs, deployment, shared branches, commits, pushes, and pull requests. Use whenever the current directory may be a workspace sources/ directory or a task spans anixpkgs and one or more dependency repositories.
---

# Workspace development

## Establish the workspace

At the start of coding work, inspect the current directory before choosing where to clone or edit. Treat it as a devshell workspace's `sources/` directory when its basename is `sources` and its parent has workspace markers such as `shell.nix`, `.envrc`, or `data/`. Also inspect its immediate children for Git repositories.

When in such a `sources/` directory:

- Keep all development for the task inside that workspace.
- Reuse repositories already present there.
- Add a needed repository to the workspace rather than cloning or editing it elsewhere. Prefer the workspace's `dev`/`addsrc` tooling when available.
- Put generated datasets, logs, exports, databases, caches, and other task data that must not be committed in the workspace-level `data/` directory, not inside a source repository. This is the persistent data directory beside `sources/` (that is, `../data/` when the current directory is `sources/`).
- Inspect `git status`, the current branch, and remotes separately in every repository before editing. Preserve unrelated work.

Do not infer the following repository roles unless the named repository is actually present in this workspace:

- `anixpkgs/` is the monorepo hub. It packages dependencies and deploys code to local or remote machines.
- `flasks/` owns the source for the Flask-based UIs that `anixpkgs` packages and deploys. Make UI implementation changes in `flasks`, not in stale or generated copies under `anixpkgs`.
- `anixdata/` owns binary/blob assets such as images. Keep blobs out of `anixpkgs`; add them to `anixdata` and update the `anixdata` flake input in `anixpkgs`.

Distinguish uncommitted task data from versioned assets: keep the former in the workspace `data/` directory and commit the latter to `anixdata/` when the project must distribute or reproduce them.

## Coordinate cross-repository work

For every cross-repository change involving `anixpkgs`:

1. Choose one descriptive side-branch name, normally `dev/<feature>` or `fix/<bug>`.
2. Use that exact branch name in `anixpkgs` and every involved dependency repository. Never do cross-repository development directly on a default branch.
3. Implement and test dependency changes in their owning repositories. Use temporary local source overrides for rapid integration testing when useful.
4. At authorized delivery checkpoints, commit coherent work and push the shared branch in every involved repository. Do not leave the hub pointing at an unpushed commit.
5. Open dependency PRs and the `anixpkgs` hub PR. Cross-reference them in both directions; the `anixpkgs` PR description must link every dependency PR and state merge/re-pin ordering.

The coding agent may create commits, push side branches, and open or update all required PRs without waiting for the user to perform those steps. NEVER merge a PR or enable auto-merge: only the user may merge. Leave all dependency and hub PRs open for the user's review and merge action, and clearly report the required merge order.

Before presenting or delivering the result, report the branch, commit, push, PR, and test state for each repository rather than treating the workspace as one Git repository.

## Wire remote dependency branches into anixpkgs

The `anixpkgs` hub PR MUST include changes to both `flake.nix` and `flake.lock` for each changed flake dependency:

1. In `flake.nix`, point the input at the dependency's pushed side branch, using an unambiguous remote ref such as `github:goromal/<repo>?ref=refs/heads/dev/<feature>`.
2. Refresh only the intended input, for example with `nix flake update <input-name>`, and review `flake.lock` to confirm that its owner, repository, revision, and ref correspond to the pushed dependency branch.
3. Commit both files in `anixpkgs`. A filesystem path override or a lock file that merely captures an unpublished local commit is not PR-ready.

Use local path inputs in `flake.nix` only as temporary local-development state. Restore the remote side-branch URL and regenerate the lock before committing or pushing.

## Keep local-build local

`pkgs/nixos/dependencies.nix` normally contains `local-build = false;`. Local deployment tools may temporarily change it to `true` so NixOS evaluates the working `anixpkgs` checkout instead of a published tag. This is useful for local rapid development, but it MUST NEVER be pushed to a remote PR.

Before every `anixpkgs` commit or push:

```bash
git diff --check
git diff --cached --check
git grep -n 'local-build = true' -- pkgs/nixos/dependencies.nix
git diff -- flake.nix flake.lock pkgs/nixos/dependencies.nix
```

If `local-build = true` or a local filesystem flake input appears, restore remote-safe state before pushing. Then verify that `flake.nix` and `flake.lock` still target every pushed dependency side branch and that the hub PR links the corresponding PRs.
