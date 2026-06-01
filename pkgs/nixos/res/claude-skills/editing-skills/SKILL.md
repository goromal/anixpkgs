---
name: editing-skills
description: Use when about to edit, create, or delete a Claude Code skill. Skills are symlinked from anixpkgs source — direct edits to ~/.claude/skills/ are not persistent.
---

## How skills are deployed on this machine

Skill files at `~/.claude/skills/<name>/SKILL.md` are **symlinks** managed by home-manager via anixpkgs. Editing them directly will either fail (read-only) or be overwritten on the next deploy.

**Source files live in:**
```
~/sources/anixpkgs/pkgs/nixos/res/claude-skills/<name>/SKILL.md
```
(or the equivalent path in whichever anixpkgs clone is being worked on)

## To edit an existing skill

1. Edit the source file in anixpkgs at the path above.
2. Deploy: `anix-upgrade --local -s /path/to/anixpkgs`

## To create a new skill

1. Create the source file:
   ```
   pkgs/nixos/res/claude-skills/<skill-name>/SKILL.md
   ```
2. **Stage it** — `git add pkgs/nixos/res/claude-skills/<skill-name>/SKILL.md` (required before `anix-upgrade` will see it).
3. Add an entry to the `skills` list in `pkgs/nixos/claude-defaults.nix`:
   ```nix
   { name = "<skill-name>"; file = ./res/claude-skills/<skill-name>/SKILL.md; }
   ```
4. Deploy: `anix-upgrade --local -s /path/to/anixpkgs`

## To delete a skill

1. Remove its entry from the `skills` list in `claude-defaults.nix`.
2. Delete the source file.
3. Deploy to remove the symlink from `~/.claude/skills/`.
