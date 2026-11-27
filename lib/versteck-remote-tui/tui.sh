# shellcheck shell=bash
# メニューと、gum を呼ぶ小さな部品

# 失敗の文言は標準エラーに出す（$(...) で結果を受け取る関数の中からも画面に残るように）
vrt_ui_error() {
  if vrt_have_command gum; then
    gum style --foreground 1 "$1" >&2
  else
    printf '%s\n' "$1" >&2
  fi
}

vrt_ui_confirm() {
  gum confirm --default=false --affirmative "はい" --negative "いいえ" "$1"
}

vrt_menu_header() {
  printf 'versteck-remote-tui %s | %s\nバックエンド: %s' \
    "$VRT_VERSION" "$(vrt_auth_label)" "$(vrt_backend_path)"
}

vrt_tui() {
  local choice rc
  if ! vrt_have_command gum || ! vrt_have_command jq; then
    echo "gum が見つかりません（または jq が見つかりません）。メニューを出せないので、シェルへ降ります（TUI の記録の外です）。" >&2
    vrt_drop_to_shell
    return 1
  fi
  vrt_auth_init tui
  rc=$?
  if ((rc != 0)); then
    vrt_ui_error "$VRT_AUTH_ERROR"
    echo "メニューを出せないので、シェルへ降ります（TUI の記録の外です）。" >&2
    vrt_drop_to_shell
    return 1
  fi
  while :; do
    choice=$(gum choose --header "$(vrt_menu_header)" \
      "状態の一覧" "セッションを覗く" "セッションを止める" "監査ログ" \
      "止め方の手順" "シェルへ降りる" "終了") || break
    case $choice in
      "状態の一覧") vrt_screen_status ;;
      "セッションを覗く") vrt_screen_peek ;;
      "セッションを止める") vrt_screen_stop ;;
      "監査ログ") vrt_screen_audit ;;
      "止め方の手順") vrt_screen_kill_switches ;;
      "シェルへ降りる") vrt_screen_shell ;;
      *) break ;;
    esac
  done
  vrt_auth_cleanup
  return 0
}
