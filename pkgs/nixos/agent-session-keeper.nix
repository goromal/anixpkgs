# Keeps UI agent sessions (Agent UI, and the Folio/budget/Assistant companions)
# alive across reboots and backend restarts. tmux sessions die with the machine,
# so each session records what it needs to come back under
# ~/.local/state/agent-sessions/<socket>/<session>.json:
#   - args:     the UI session command's arguments (exported by that command as
#               AGENT_SESSION_ARGS), replayed against the *current* session
#               command so a restore never depends on a GC-able store path;
#   - agent_id: the agent's resumable conversation id. Claude gets one up front
#               (--session-id); Codex can't be told one, so the watcher reads it
#               off the thread-writer lock the running codex holds open;
#   - options:  the session's tmux user options (@label, @title, ...).
# `run` wraps the agent launch, keeps that record current, and deletes it when
# the agent exits cleanly (the user ended it). The UIs delete it on Kill. A record
# left behind therefore means "this session was still running": `restore`
# (the backend unit's ExecStartPost) recreates each one whose tmux session is
# missing, resuming the conversation.
{ pkgs, lib }:
let
  stateRoot = "$HOME/.local/state/agent-sessions";
  toolsPath = lib.makeBinPath [
    pkgs.tmux
    pkgs.jq
    pkgs.coreutils
    pkgs.diffutils
    pkgs.procps
    pkgs.util-linux
  ];

  run = pkgs.writeShellApplication {
    name = "agent-session-run";
    # Tools go on PATH only for this script and its watcher, not for the agent:
    # the agent keeps the caller's PATH (a devshell's, for Agent UI).
    runtimeInputs = [ ];
    text = ''
      if [ "$#" -lt 1 ]; then
        echo "usage: agent-session-run AGENT [ARGS...]" >&2
        exit 2
      fi
      agent="$1"
      shift
      args=("$@")
      agent_path="$PATH"
      PATH="${toolsPath}:$PATH"

      resume="''${AGENT_RESUME_ID:-}"
      unset AGENT_RESUME_ID
      session_args="''${AGENT_SESSION_ARGS:-}"
      unset AGENT_SESSION_ARGS

      # Outside tmux, or launched without restorable args: nothing to keep.
      if [ -z "''${TMUX:-}" ] || [ -z "''${TMUX_PANE:-}" ] || [ -z "$session_args" ]; then
        PATH="$agent_path" exec "$agent" "''${args[@]}"
      fi
      socket="$(basename "''${TMUX%%,*}")"
      name="$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}')"
      state_dir="${stateRoot}/$socket"
      state="$state_dir/$name.json"
      mkdir -p "$state_dir"
      chmod 700 "${stateRoot}" "$state_dir"

      agent_id=""
      cmd=()
      build() {
        case "$agent" in
          claude)
            if [ -n "$1" ]; then
              agent_id="$1"
              cmd=(claude --resume "$1" "''${args[@]}")
            else
              agent_id="$(uuidgen)"
              cmd=(claude --session-id "$agent_id" "''${args[@]}")
            fi
            ;;
          codex)
            agent_id="$1"
            if [ -n "$1" ]; then
              cmd=(codex resume "''${args[@]}" "$1")
            else
              cmd=(codex "''${args[@]}")
            fi
            ;;
          *)
            agent_id=""
            cmd=("$agent" "''${args[@]}")
            ;;
        esac
      }

      # Codex's current thread id: the lock it holds open under
      # ~/.codex/thread-writer-locks/<uuid>.lock (also its rollout file's id).
      codex_id() {
        local pid fd link pids kids
        mapfile -t kids < <(pgrep -P "$$" || true)
        pids=("''${kids[@]}")
        if [ "''${#kids[@]}" -gt 0 ]; then
          mapfile -t -O "''${#pids[@]}" pids < <(pgrep -P "$(IFS=,; echo "''${kids[*]}")" || true)
        fi
        for pid in "''${pids[@]}"; do
          for fd in /proc/"$pid"/fd/*; do
            link="$(readlink "$fd" 2>/dev/null || true)"
            if [[ "$link" =~ /thread-writer-locks/([0-9a-f-]{36})\.lock$ ]]; then
              echo "''${BASH_REMATCH[1]}"
              return 0
            fi
          done
        done
      }

      # Option commands reject the exact-match "=name" target; session names
      # carry a random suffix, so a prefix match can't pick the wrong one.
      options() {
        local opt
        tmux show-options -t "$name" 2>/dev/null | while read -r opt _; do
          case "$opt" in
            @*) jq -n --arg k "$opt" --arg v "$(tmux show-options -v -t "$name" "$opt")" '{($k): $v}' ;;
          esac
        done | jq -s 'add // {}'
      }

      # Rewrite the record when anything changed: fast at first (codex picks
      # its thread id a moment after launch), then every 30 s.
      watch() {
        local id="$1" tick=0 opts
        while :; do
          # Past the first write, a missing record means a UI's Kill forgot this
          # session: never write it back.
          if [ "$tick" -gt 0 ] && [ ! -e "$state" ]; then
            return 0
          fi
          if [ "$agent" = codex ]; then
            id="$(codex_id)" || true
            [ -n "$id" ] || id="$1"
          fi
          opts="$(options)" || opts='{}'
          jq -n --arg name "$name" --arg socket "$socket" --arg agent "$agent" \
            --arg id "$id" --argjson args "$session_args" --argjson options "$opts" \
            '{name: $name, socket: $socket, agent: $agent, agent_id: $id, args: $args, options: $options}' \
            >"$state.tmp" && { cmp -s "$state.tmp" "$state" || mv "$state.tmp" "$state"; }
          rm -f "$state.tmp"
          tick=$((tick + 1))
          if [ "$tick" -lt 12 ]; then sleep 5; else sleep 30; fi
        done
      }

      build "$resume"
      watch "$agent_id" &
      watcher=$!
      started="$(date +%s)"
      set +e
      PATH="$agent_path" "''${cmd[@]}"
      rc=$?
      # A resume that dies at once (transcript gone or unreadable) falls back to
      # a fresh conversation rather than closing the session.
      if [ -n "$resume" ] && [ "$rc" -ne 0 ] && [ $(($(date +%s) - started)) -lt 15 ]; then
        echo "agent-session-run: could not resume $agent session $resume; starting a new one" >&2
        kill "$watcher" 2>/dev/null
        build ""
        watch "$agent_id" &
        watcher=$!
        PATH="$agent_path" "''${cmd[@]}"
        rc=$?
      fi
      kill "$watcher" 2>/dev/null
      wait "$watcher" 2>/dev/null
      # Clean exit = the user ended it: forget the session. A kill (tmux
      # kill-session, shutdown) never gets here, so its record survives.
      if [ "$rc" -eq 0 ]; then
        rm -f "$state" "$state.tmp"
      fi
      exit "$rc"
    '';
  };

  restore = pkgs.writeShellApplication {
    name = "agent-session-restore";
    runtimeInputs = [
      pkgs.tmux
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      if [ "$#" -ne 3 ]; then
        echo "usage: agent-session-restore SOCKET TMUX_CONFIG SESSION_COMMAND" >&2
        exit 2
      fi
      socket="$1"
      conf="$2"
      session_cmd="$3"
      dir="${stateRoot}/$socket"
      [ -d "$dir" ] || exit 0
      for f in "$dir"/*.json; do
        [ -e "$f" ] || continue
        if ! rec="$(jq -c . "$f" 2>/dev/null)"; then
          echo "agent-session-restore: dropping unreadable $f" >&2
          rm -f "$f"
          continue
        fi
        name="$(jq -r .name <<<"$rec")"
        if tmux -L "$socket" has-session -t "=$name" 2>/dev/null; then
          continue
        fi
        # The relaunched session writes a fresh record once it is running; a
        # session that can't start (e.g. its workspace was deleted) is dropped
        # instead of retried on every restart.
        rm -f "$f"
        mapfile -t args < <(jq -r '.args[]' <<<"$rec")
        id="$(jq -r '.agent_id // ""' <<<"$rec")"
        env_args=()
        if [ -n "$id" ]; then
          env_args=(-e "AGENT_RESUME_ID=$id")
        fi
        if ! tmux -L "$socket" -f "$conf" new-session -d -s "$name" "''${env_args[@]}" "$session_cmd" "''${args[@]}"; then
          echo "agent-session-restore: could not recreate $name" >&2
          continue
        fi
        while IFS= read -r opt; do
          tmux -L "$socket" set-option -t "$name" "$opt" "$(jq -r --arg k "$opt" '.options[$k]' <<<"$rec")" || true
        done < <(jq -r '.options // {} | keys[]' <<<"$rec")
        echo "agent-session-restore: restored $name''${id:+ (resuming $id)}"
        # Stagger launches: each agent costs ~1 GB once up.
        sleep 2
      done
    '';
  };
in
{
  runCommand = "${run}/bin/agent-session-run";
  restoreCommand = "${restore}/bin/agent-session-restore";
  inherit run restore stateRoot;
  # Exported by a UI session command before it reaches the agent, so the record
  # can replay it: AGENT_SESSION_ARGS="$(${exportArgs} "$@")".
  exportArgs = "${pkgs.jq}/bin/jq -cn '$ARGS.positional' --args";
}
