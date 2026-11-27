# shellcheck shell=bash
# セッションを止める。注意書きはこの画面に入るたびに必ず出す

VRT_STOP_NOTICE="止まるのはエージェントのセッションだけです。人の入口は止まりません。
確実に止まるのは VM を止めることです（手順はメニューの「止め方の手順」）。"

vrt_screen_stop() {
  local json choice rc out
  local -a names
  gum style --border normal --padding "0 1" "$VRT_STOP_NOTICE"
  json=$(vrt_fetch_status) || return 0
  mapfile -t names < <(printf '%s\n' "$json" | vrt_session_names)
  if ((${#names[@]} == 0)); then
    gum style "動いているエージェントのセッションはありません。"
    return 0
  fi
  choice=$(gum choose --header "止めるセッションを選んでください" "${names[@]}" "すべて止める" "戻る") || return 0
  case $choice in
    "戻る") return 0 ;;
    "すべて止める")
      if ! vrt_ui_confirm "$VRT_STOP_NOTICE

エージェントのセッションを ${#names[@]} 件すべて止めますか？"; then
        gum style "止めませんでした。"
        return 0
      fi
      out=$(vrt_backend stop --all)
      rc=$?
      ;;
    *)
      if ! vrt_valid_session_name "$choice"; then
        vrt_ui_error "セッション名の形が正しくありません。"
        return 0
      fi
      if ! vrt_ui_confirm "$VRT_STOP_NOTICE

セッション「$choice」を止めますか？"; then
        gum style "止めませんでした。"
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
  gum style "止めました。" "$(printf '%s' "$out" | vrt_sanitize_text)"
}
