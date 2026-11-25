# Keeps UI agent sessions (Agent UI, and the Folio/budget/Assistant companions)
# alive across reboots and backend restarts. tmux sessions die with the machine,
# so each session records what it needs to come back under
# ~/.local/state/agent-sessions/<socket>/<session>.json:
#   - args:     the UI session command's arguments (exported by that command as
#               AGENT_SESSION_ARGS), replayed against the *current* session
#               command so a restore never depends on a GC-able store path;
#   - agent_id: the agent's resumable conversation id. Claude starts with one
#               (--session-id) and reports each new one (/clear, compaction)
#               through a SessionStart hook; Codex can't be told one, so the
#               watcher reads it off the thread-writer lock codex holds open;
#   - options:  the session's tmux user options (@label, @title, ...).
# `run` wraps the agent launch, keeps that record current, and deletes it when
# the agent exits cleanly (the user ended it). The UIs delete it on Kill. A record
# left behind therefore means "this session was still running": `restore`
# (the backend unit's ExecStartPost) recreates each one whose tmux session is
# missing, resuming the conversation.
# `send` (agent-send) is the shared input path for UI composers: it pastes text
# into a session's pane as one bracketed paste and then presses Enter. The text
# is sanitized first so it cannot produce keystrokes other than that final
# Enter: a pane that hasn't enabled bracketed paste (the shell session type)
# receives the sanitized text unbracketed, with tmux turning each LF into a CR
# so every line runs, but nothing in a sanitized payload can act as Ctrl-C, an
# escape sequence, or (inside a real bracketed paste) the end-of-paste marker
# that would let the bytes after it be read as keys.
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

  # Claude SessionStart hook (startup, resume, /clear, compact): note the
  # current conversation id for the watcher. Prints nothing -- SessionStart
  # stdout would be injected into the conversation.
  claudeHook = pkgs.writeShellApplication {
    name = "agent-session-claude-hook";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      f="''${AGENT_SESSION_ID_FILE:-}"
      [ -n "$f" ] || exit 0
      id="$(jq -r '.session_id // empty' 2>/dev/null || true)"
      if [ -n "$id" ]; then
        printf '%s\n' "$id" >"$f.tmp" && mv "$f.tmp" "$f"
      fi
      exit 0
    '';
  };
  claudeSettings = builtins.toJSON {
    hooks.SessionStart = [
      {
        hooks = [
          {
            type = "command";
            command = "${claudeHook}/bin/agent-session-claude-hook";
          }
        ];
      }
    ];
  };

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
      # Where the claude hook reports the live conversation id. Only needed
      # until the watcher copies it into the record, so /tmp is fine.
      id_file="''${TMPDIR:-/tmp}/agent-session-$socket-$name.claude-id"
      export AGENT_SESSION_ID_FILE="$id_file"

      agent_id=""
      cmd=()
      build() {
        case "$agent" in
          claude)
            if [ -n "$1" ]; then
              agent_id="$1"
              cmd=(claude --resume "$1")
            else
              agent_id="$(uuidgen)"
              cmd=(claude --session-id "$agent_id")
            fi
            cmd+=(--settings ${lib.escapeShellArg claudeSettings} "''${args[@]}")
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
          case "$agent" in
            codex)
              id="$(codex_id)" || true
              [ -n "$id" ] || id="$1"
              ;;
            claude)
              if [ -s "$id_file" ]; then
                id="$(cat "$id_file")"
              fi
              ;;
          esac
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

      rm -f "$id_file"
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
        rm -f "$id_file"
        build ""
        watch "$agent_id" &
        watcher=$!
        PATH="$agent_path" "''${cmd[@]}"
        rc=$?
      fi
      kill "$watcher" 2>/dev/null
      wait "$watcher" 2>/dev/null
      rm -f "$id_file" "$id_file.tmp"
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

  # Delivers text typed in a UI's composer to an agent pane: one bracketed paste
  # (so multi-line text is not submitted line by line), then Enter as its own
  # keystroke after a pause, because Claude Code and Codex treat input that
  # arrives inside a paste burst as more paste (a newline, not "submit"). Empty
  # input just presses Enter. Callers validate the target; this only drives tmux.
  # Stdin is sanitized (C0 controls other than TAB/LF, and DEL, are dropped)
  # before it reaches the pane: an embedded end-of-paste marker (ESC [ 201 ~)
  # would otherwise close the bracketed paste early, and whatever followed it
  # -- Ctrl-C, CR, more escapes -- would be delivered as real keystrokes rather
  # than pasted text, letting a companion forward keys the owner never typed.
  # A pane that hasn't enabled bracketed paste (the shell session type) gets
  # the sanitized text unbracketed, and tmux turns each LF into a CR, so it
  # runs line by line, same as a normal paste there.
  send = pkgs.writeShellApplication {
    name = "agent-send";
    runtimeInputs = [
      pkgs.tmux
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      if [ "$#" -ne 3 ] || [ "$1" != -L ]; then
        echo "usage: agent-send -L SOCKET TARGET  (text on stdin)" >&2
        exit 2
      fi
      socket="$2"
      target="$3"
      t() { tmux -L "$socket" "$@"; }

      # One send at a time per pane: two concurrent callers (two tabs, two
      # devices) would otherwise interleave as paste A, paste B, Enter, Enter
      # and merge into one prompt. flock is released by the kernel if this
      # process dies, so a crashed send can't wedge the pane; the wait stays
      # under the UI backends' request timeouts. The lock lives next to the
      # tmux socket dir (per-user, 0700) rather than XDG_RUNTIME_DIR/tmp
      # directly, which other users on the same host can also write to.
      lockdir="''${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"
      mkdir -p "$lockdir"
      chmod 700 "$lockdir"
      lock="$lockdir/agent-send-$socket-''${target//\//_}.lock"
      exec 9>>"$lock"
      if ! flock -w 5 9; then
        echo "agent-send: $target is busy" >&2
        exit 1
      fi

      # A pane scrolled back into copy-mode would swallow the keys. Capture the
      # mode into a variable rather than branching on the command directly, so
      # a missing target fails this line (set -e) before anything is buffered.
      mode="$(t display-message -p -t "$target" '#{pane_in_mode}')"
      if [ "$mode" = 1 ]; then
        t send-keys -t "$target" -X cancel
      fi

      buf="agent-send-$$"
      tmp="$(mktemp)"
      trap 'rm -f "$tmp"; t delete-buffer -b "$buf" 2>/dev/null || true' EXIT
      tr -d '\000-\010\013-\037\177' >"$tmp"
      if [ -s "$tmp" ]; then
        t load-buffer -b "$buf" "$tmp"
        t paste-buffer -p -d -b "$buf" -t "$target"
        sleep 0.15
      fi
      t send-keys -t "$target" Enter
    '';
  };
in
{
  runCommand = "${run}/bin/agent-session-run";
  restoreCommand = "${restore}/bin/agent-session-restore";
  sendCommand = "${send}/bin/agent-send";
  inherit
    run
    restore
    send
    stateRoot
    ;
  # Exported by a UI session command before it reaches the agent, so the record
  # can replay it: AGENT_SESSION_ARGS="$(${exportArgs} "$@")".
  exportArgs = "${pkgs.jq}/bin/jq -cn '$ARGS.positional' --args";
}
