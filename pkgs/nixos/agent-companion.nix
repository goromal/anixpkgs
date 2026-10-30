# Shared builder for "agent companion" terminals embedded in app UIs (Folio,
# budget, Assistant). Each companion runs Claude/Codex inside tmux sessions on a
# dedicated socket, served to the browser by a localhost ttyd behind an nginx
# auth_request gate. The app backend owns the session API. Sessions run in
# throwaway temp dirs, or (with workRepo) all in one persistent repo checkout.
{ pkgs, lib }:
with import ./dependencies.nix;
{
  # Prefix for binaries, the tmux socket and session names:
  # "<name>-agent-session", socket "<name>-agent", "<name>-agent--<agent>--<id>".
  name,
  agents,
  # Skill dir name under ~/.<agent>/skills/ to preload into every session.
  skill,
  # Phrase naming the host app in the primer, e.g. "the Folio reading app".
  appLabel,
  # What the skill governs, completing "follow it for <skillScope>", e.g.
  # "all mcp__folio__* work".
  skillScope,
  terminalPort,
  terminalBasePath,
  authHeader,
  # The systemd unit that spawns the tmux sessions (ttyd starts after it).
  backendService,
  homeDir,
  checkOrigin ? false,
  # "owner/name" GitHub repo. When set, the session WORKDIR is a durable checkout
  # of it shared by every session: the session clones it if missing and pulls it
  # (best effort) before launching, and trusts that dir itself.
  workRepo ? null,
}:
let
  prefix = "${name}-agent";
  agentAlternation = lib.concatStringsSep "|" agents;

  # Same llm-agents CLIs the claude/codex agent components install (home.packages),
  # but placed on the backend service PATH so a spawned `exec claude`/`codex` in a
  # plain temp dir resolves. Unlike Agent UI, the companion runs the agent in a bare
  # temp dir with NO devshell/direnv wrapping, so this PATH is the agent's entire
  # userland: it must carry a shell and the standard GNU tools the agent shells out
  # to (Claude Code's Bash tool runs `bash -c`), not just enough to exec the CLI.
  agentPackages = {
    claude = anixpkgs.flakeInputs.llm-agents.packages.${pkgs.system}.claude-code;
    codex = anixpkgs.flakeInputs.llm-agents.packages.${pkgs.system}.codex;
  };

  # Appended to an existing script line (not its own line) so companions without
  # workRepo keep byte-identical session scripts.
  repoSync = lib.optionalString (workRepo != null) (
    "\n"
    + ''
      # Shared durable checkout: make sure it exists and is current. A failed
      # clone/pull (offline, auth) must not block the agent launch.
      if [ ! -d "$1/.git" ]; then
        mkdir -p "$(dirname "$1")"
        gh repo clone ${workRepo} "$1" || echo "${prefix}-session: clone of ${workRepo} failed" >&2
      else
        git -C "$1" pull --rebase --autostash --quiet || echo "${prefix}-session: git pull failed" >&2
      fi
      mkdir -p "$1"''
  );

  tmuxConf = pkgs.writeText "${prefix}-tmux.conf" ''
    set -g mouse on
    set -g history-limit 50000
    # Smooth one-line scrolling in copy-mode (mirrors agent-ui): a finger-drag in
    # the companion terminal pages scrollback line by line, not a screen at a time.
    bind -T copy-mode    Up   send-keys -X scroll-up
    bind -T copy-mode    Down send-keys -X scroll-down
    bind -T copy-mode-vi Up   send-keys -X scroll-up
    bind -T copy-mode-vi Down send-keys -X scroll-down
  '';

  session = pkgs.writeShellApplication {
    name = "${prefix}-session";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.util-linux
    ]
    ++ lib.optionals (workRepo != null) [
      pkgs.gh
      pkgs.git
      pkgs.openssh
    ];
    text = ''
      if [ "$#" -ne 2 ]; then
        echo "usage: ${prefix}-session WORKDIR AGENT" >&2
        exit 2
      fi
      case "$2" in
        ${agentAlternation}) ;;
        *) echo "${prefix}-session: unsupported agent" >&2; exit 2 ;;
      esac
      # No devshell wraps this session, so nothing sets SHELL; Claude Code's Bash
      # tool would fall back to /bin/bash, which doesn't exist on NixOS. Point it
      # at the bash on the service PATH so shell tool calls work.
      export SHELL="${pkgs.bashInteractive}/bin/bash"
      # Append the login-shell profile dirs (setuid wrappers like sudo, user and
      # system packages) so agents see the same commands a terminal does.
      export PATH="$PATH:/run/wrappers/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"${repoSync}
      # Pre-accept Claude Code's workspace-trust dialog so a headless companion
      # launch does not stall on it. Trust the stable spool parent (not each
      # ephemeral session dir): claude honors an ancestor's trust, so every
      # session under the spool inherits it without accumulating stale
      # ~/.claude.json entries. Idempotent, flock-guarded.
      if [ "$2" = claude ]; then
        spool="${if workRepo != null then "$1" else "$(dirname \"$1\")"}"
        cfg="$HOME/.claude.json"
        (
          flock 9
          tmp="$(mktemp "$HOME/.claude.json.${name}.XXXXXX")"
          if [ -f "$cfg" ]; then base="$cfg"; else base="$tmp"; printf '{}' >"$base"; fi
          if jq --arg d "$spool" '.projects[$d].hasTrustDialogAccepted = true' "$base" >"$tmp.out"; then
            mv "$tmp.out" "$cfg"
          fi
          rm -f "$tmp" "$tmp.out"
        ) 9>"$HOME/.claude.json.${name}.lock" || true
      fi
      cd "$1"
      # Codex has no ancestor trust (unlike claude above) and would show its
      # folder-trust dialog in every fresh session dir, so trust the session dir
      # for this launch only. Inline-table form: a dotted projects."<dir>" key
      # override is ignored. Nothing is written to ~/.codex/config.toml.
      args=()
      if [ "$2" = codex ]; then
        args+=(-c "projects={$(jq -n --arg d "$1" '$d')={trust_level=\"trusted\"}}")
      fi
      # Preload the ${skill} skill into the agent's instructions so every
      # companion session knows the app's workflow without being asked to
      # load it. Missing skill file -> launch the agent unprimed.
      skill="$HOME/.$2/skills/${skill}/SKILL.md"
      if [ ! -r "$skill" ]; then
        exec "$2" "''${args[@]}"
      fi
      primer="You are running inside ${appLabel}'s agent companion. The ${skill} skill is preloaded below; follow it for ${skillScope}.

      $(cat "$skill")"
      case "$2" in
        # -c values parse as TOML; JSON-encode so the markdown is one TOML string.
        codex) exec codex "''${args[@]}" -c "developer_instructions=$(jq -Rs . <<<"$primer")" ;;
        *) exec "$2" --append-system-prompt "$primer" ;;
      esac
    '';
  };

  attach = pkgs.writeShellApplication {
    name = "${prefix}-attach";
    runtimeInputs = [
      pkgs.tmux
      pkgs.coreutils
    ];
    text = ''
      if [ "$#" -ne 1 ] || [[ ! "$1" =~ ^${prefix}--(${agentAlternation})--[0-9a-f]{8}$ ]]; then
        echo "${prefix}-attach: invalid session" >&2
        exit 2
      fi
      # When the session is gone (agent exited), hold the pane with a notice
      # instead of exiting, so ttyd doesn't silently reconnect-loop.
      hold() {
        printf '\r\n\033[1;33mSession ended.\033[0m Close this panel or start a new session.\r\n'
        sleep infinity
      }
      if ! tmux -L ${prefix} has-session -t "$1" 2>/dev/null; then
        hold
      fi
      tmux -L ${prefix} attach-session -t "$1" || true
      if ! tmux -L ${prefix} has-session -t "$1" 2>/dev/null; then
        hold
      fi
    '';
  };
in
{
  inherit tmuxConf;
  socket = prefix;
  sessionCommand = "${session}/bin/${prefix}-session";
  attachCommand = "${attach}/bin/${prefix}-attach";
  servicePath = [
    pkgs.bashInteractive
    pkgs.tmux
    pkgs.procps
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gawk
    pkgs.findutils
    pkgs.which
    pkgs.gitMinimal
  ]
  ++ map (agent: agentPackages.${agent}) agents;
  terminalService = {
    description = "${name} agent companion ttyd";
    after = [ "${backendService}.service" ];
    wants = [ "${backendService}.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.tmux ];
    environment.HOME = homeDir;
    serviceConfig = {
      Type = "simple";
      ExecStart = lib.concatStringsSep " " (
        [
          "${pkgs.ttyd}/bin/ttyd"
          "--port ${toString terminalPort}"
          "--interface 127.0.0.1"
          "--writable"
          "--url-arg"
        ]
        ++ lib.optional checkOrigin "--check-origin"
        ++ [
          "--auth-header ${authHeader}"
          "--base-path ${terminalBasePath}"
          "${attach}/bin/${prefix}-attach"
        ]
      );
      Restart = "always";
      RestartSec = 3;
      User = "andrew";
      Group = "dev";
      UMask = "0077";
    };
  };
}
