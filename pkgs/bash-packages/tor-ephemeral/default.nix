{
  writeArgparseScriptBin,
  tor-browser,
}:
writeArgparseScriptBin "tor-ephemeral"
  ''
    usage: tor-ephemeral [URL ...]

    Launch Tor Browser with a throwaway, RAM-backed profile. All state
    (profile, history, torrc, caches) lives in a tmpfs directory under
    $XDG_RUNTIME_DIR and is deleted on exit, so nothing persists across
    launches and the real user profile is never touched. Any URLs given
    are opened on start.
  ''
  [ ]
  ''
    runtime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    run="$(mktemp -d "''${runtime}/tor-ephemeral.XXXXXX")"
    trap 'rm -rf "$run"' EXIT

    HOME="$run" \
    XDG_DATA_HOME="$run/.local/share" \
    XDG_CONFIG_HOME="$run/.config" \
    XDG_CACHE_HOME="$run/.cache" \
    XDG_STATE_HOME="$run/.local/state" \
      ${tor-browser}/bin/tor-browser "$@"
  ''
