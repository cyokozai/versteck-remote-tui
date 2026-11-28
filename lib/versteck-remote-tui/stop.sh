# shellcheck shell=bash
# セッションを止める。注意書きはこの画面に入るたびに必ず出す

# 枠の中の各行は表示幅 74 以下（全角は 2）。枠の線と余白を足して 78 桁になり、80 桁の端末で崩れない
VRT_STOP_NOTICE="Only agent sessions are stopped. The human entrance keeps running.
The only sure way to stop everything is to stop the VM
(see Kill switches)."

# 「すべて止める」の確認の問い。status に載っている件数（名前の形が合わないものを含む）を添える。
# 各行は注意書きと同じく表示幅 74 以下
vrt_stop_all_question() {
  if ((VRT_SESSION_TOTAL == 0)); then
    printf '%s\n' "status lists no sessions." "Stop all agent sessions anyway?"
  elif ((VRT_SESSION_REJECTED > 0)); then
    printf '%s\n' "Stop all ${VRT_SESSION_TOTAL} agent session(s)?" \
      "(includes ${VRT_SESSION_REJECTED} with a malformed name)"
  else
    echo "Stop all ${VRT_SESSION_TOTAL} agent session(s)?"
  fi
}

vrt_screen_stop() {
  local json choice rc out
  gum style --border normal --padding "0 1" -- "$VRT_STOP_NOTICE"
  json=$(vrt_fetch_status) || return 0
  vrt_load_sessions "$json" || return 0
  if ((VRT_SESSION_TOTAL == 0)); then
    vrt_ui_say "No agent sessions are running."
  fi
  # 一覧に出せる名前が 0 件でも、status が取れていれば「すべて止める」は選べる
  choice=$(vrt_ui_choose --header="Choose a session to stop" -- "${VRT_SESSION_NAMES[@]}" "Stop all" "Back") || return 0
  case $choice in
    "Back") return 0 ;;
    "Stop all")
      if ! vrt_ui_confirm "$VRT_STOP_NOTICE

$(vrt_stop_all_question)"; then
        vrt_ui_say "Nothing was stopped."
        return 0
      fi
      out=$(vrt_backend stop --all)
      rc=$?
      ;;
    *)
      if ! vrt_valid_session_name "$choice"; then
        vrt_ui_error "The session name is malformed."
        return 0
      fi
      if ! vrt_ui_confirm "$VRT_STOP_NOTICE

Stop session \"$choice\"?"; then
        vrt_ui_say "Nothing was stopped."
        return 0
      fi
      out=$(vrt_backend stop "$choice")
      rc=$?
      ;;
  esac
  if ((rc != 0)); then
    vrt_ui_error "$(vrt_backend_error_message "$rc")"
    return 0
  fi
  vrt_ui_say "Stopped." "$(printf '%s' "$out" | vrt_sanitize_text)"
}
