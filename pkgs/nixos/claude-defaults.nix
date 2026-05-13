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
    # Filesystem read
    "Bash(ls:*)"
    "Bash(find:*)"
    "Bash(cat:*)"
    "Bash(grep:*)"
    "Bash(rg:*)"
    "Bash(echo:*)"
    "Bash(which:*)"
    "Bash(pwd:*)"
    # Write ops (superpowers pre-commit hook guards commits)
    "Bash(git add:*)"
    "Bash(git commit:*)"
    # Build tools
    "Bash(npm run:*)"
    "Bash(cargo build:*)"
    "Bash(nix build:*)"
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
