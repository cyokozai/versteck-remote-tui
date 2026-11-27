# shellcheck shell=bash
# セッションを覗く（読み取り専用）。バックエンドの peek が出す画面の文字を pager で見せるだけで、
# tmux attach はしない。

vrt_screen_peek() {
  local json name out rc next
  json=$(vrt_fetch_status) || return 0
  vrt_load_sessions "$json" || return 0
  if ((${#VRT_SESSION_NAMES[@]} == 0)); then
    ((VRT_SESSION_REJECTED > 0)) || vrt_ui_say "No agent sessions are running."
    return 0
  fi
  name=$(vrt_ui_choose --header="Choose a session to peek at (read-only)" -- "${VRT_SESSION_NAMES[@]}" "Back") || return 0
  [[ $name != "Back" ]] || return 0
  vrt_valid_session_name "$name" || return 0
  while :; do
    out=$(vrt_backend peek "$name")
    rc=$?
    if ((rc != 0)); then
      vrt_ui_error "$(vrt_backend_error_message "$rc")"
      return 0
    fi
    {
      printf 'Session %s screen (read-only, fetched %s)\n\n' "$name" "$(date '+%H:%M:%S')"
      printf '%s\n' "$out" | vrt_sanitize_text
    } | gum pager
    next=$(vrt_ui_choose --header="Session $name" -- "Reload" "Back") || return 0
    [[ $next == "Reload" ]] || return 0
  done
}
