# Default Claude Code configuration values, referenced by pc-base.nix options.
# Kept in a separate file to avoid bloating the options declarations.
let
  sp = "$HOME/.claude/plugins/marketplaces/superpowers-extended-cc-marketplace";
in
{
  marketplaces = [
    "DevonMorris/claude-ctags"
    "pcvelz/superpowers"
  ];

  plugins = [
    "claude-ctags@claude-ctags"
    "code-review@claude-plugins-official"
    "frontend-design@claude-plugins-official"
    "github@claude-plugins-official"
    "feature-dev@claude-plugins-official"
    "pr-review-toolkit@claude-plugins-official"
    "superpowers-extended-cc@superpowers-extended-cc-marketplace"
  ];

  permissionsAllow = [
    # Read-only git
    "Bash(git log:*)"
    "Bash(git status:*)"
    "Bash(git diff:*)"
    "Bash(git show:*)"
    # General git
    "Bash(git add:*)"
    "Bash(git commit:*)"
    "Bash(git push:*)"
    "Bash(git pull:*)"
    "Bash(git stash:*)"
    "Bash(git checkout:*)"
    "Bash(git rebase:*)"
    # GitHub CLI
    "Bash(gh:*)"
    # Filesystem read
    "Bash(ls:*)"
    "Bash(find:*)"
    "Bash(cat:*)"
    "Bash(grep:*)"
    "Bash(rg:*)"
    "Bash(echo:*)"
    "Bash(which:*)"
    "Bash(pwd:*)"
    # Data processing
    "Bash(python3:*)"
    "Bash(jq:*)"
    # Build tools
    "Bash(npm run:*)"
    "Bash(cargo build:*)"
    "Bash(nix build:*)"
    "Bash(nix-build:*)"
    "Bash(nix eval:*)"
    "Bash(nix flake:*)"
    "Bash(nix search:*)"
    # System management
    "Bash(systemctl:*)"
    "Bash(journalctl:*)"
    # This-system tools
    "Bash(anix-upgrade:*)"
    "Bash(claude-setup)"
    "Bash(rtk:*)"
    # File access
    "Read(/data/andrew/**)"
    # Web fetch
    "WebFetch(domain:github.com)"
    "WebFetch(domain:raw.githubusercontent.com)"
    # MCP read tools
    "mcp__vikunja__vikunja_list_tasks"
    "mcp__vikunja__vikunja_list_projects"
    "mcp__vikunja__vikunja_get_task"
    "mcp__vikunja__vikunja_get_project"
    "mcp__vikunja__vikunja_get_comments"
    "mcp__wiki__wiki_get_page"
    "mcp__wiki__wiki_get_page_md"
    "mcp__wiki__wiki_list_pages"
    "mcp__wiki__wiki_search"
    "mcp__notion__notion_list_blocks"
    "mcp__notion__notion_list_subpages"
  ];

  skills = [
    { name = "anixpkgs-deploy"; file = ./res/claude-skills/anixpkgs-deploy/SKILL.md; }
    { name = "anixpkgs-packages"; file = ./res/claude-skills/anixpkgs-packages/SKILL.md; }
    { name = "editing-skills"; file = ./res/claude-skills/editing-skills/SKILL.md; }
    { name = "rtk-usage"; file = ./res/claude-skills/rtk-usage/SKILL.md; }
    { name = "wiki-usage"; file = ./res/claude-skills/wiki-usage/SKILL.md; }
  ];

  hooks = [
    {
      event = "SessionStart";
      matcher = "startup|clear|compact";
      command = "\"${sp}/hooks/run-hook.cmd\" session-start";
      async = false;
    }
    {
      event = "PreToolUse";
      matcher = "Bash";
      command = "bash \"${sp}/hooks/examples/pre-commit-check-tasks.sh\"";
    }
    {
      event = "PostToolUse";
      matcher = "TaskUpdate";
      command = "bash \"${sp}/hooks/examples/post-task-complete-revalidate.sh\"";
    }
    {
      event = "Stop";
      matcher = "";
      command = "bash \"${sp}/hooks/examples/stop-revalidate-user-gates.sh\"";
    }
    {
      event = "PreToolUse";
      matcher = "TaskUpdate";
      command = "bash \"${sp}/hooks/examples/pre-task-blockedby-enforce.sh\"";
    }
  ];
}
