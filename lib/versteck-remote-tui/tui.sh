# shellcheck shell=bash
# メニューと、gum を呼ぶ小さな部品
# gum に位置引数を渡すときは必ず -- の後ろに置く。外から来た文字列（バックエンドの出力・セッション名・
# 監査ログの中身）が - で始まると、gum はそれをフラグと読んで失敗するため。

# 失敗の文言は標準エラーに出す（$(...) で結果を受け取る関数の中からも画面に残るように）
vrt_ui_error() {
  if vrt_have_command gum; then
    gum style --foreground 1 -- "$1" >&2
  else
    printf '%s\n' "$1" >&2
  fi
}

# 文言を出す（枠なし）
vrt_ui_say() {
  gum style -- "$@"
}

vrt_ui_confirm() {
  gum confirm --default=false --affirmative "Yes" --negative "No" -- "$1"
}

vrt_stderr_is_tty() {
  [[ -t 2 ]]
}

# gum choose を呼ぶ。終了コードはそのまま返す（0 選んだ / 1 Esc / 130 Ctrl-C）。
# gum 0.17.0 は Esc で「nothing selected」を標準エラーに 1 行出して 1 で終わる。gum は画面も標準エラーに
# 描くので、標準エラーを捨てると操作の表示まで消える。そこで端末のときだけ、終わった後にその 1 行を消す
# （カーソルを 1 行上げて行を消す）。
vrt_ui_choose() {
  local rc
  gum choose "$@"
  rc=$?
  if ((rc == 1)) && vrt_stderr_is_tty; then
    printf '\033[1A\033[2K' >&2
  fi
  return "$rc"
}

vrt_menu_header() {
  printf 'versteck-remote-tui %s | %s\nBackend: %s' \
    "$VRT_VERSION" "$(vrt_auth_label)" "$(vrt_backend_path)"
}

# 戻り値: 0「終了」・Esc / 130 メニューで Ctrl-C（gum の中断） / 1 メニューを出せずシェルへ降りられなかった
vrt_tui() {
  local choice rc
  local -a missing=()
  vrt_have_command gum || missing+=(gum)
  vrt_have_command jq || missing+=(jq)
  if ((${#missing[@]} > 0)); then
    printf '%s not found. The menu cannot be shown, so dropping to a shell (outside the TUI record).\n' \
      "$(vrt_join " and " "${missing[@]}")" >&2
    vrt_drop_to_shell
    return 1
  fi
  vrt_auth_init tui
  rc=$?
  if ((rc != 0)); then
    vrt_ui_error "$VRT_AUTH_ERROR"
    echo "The menu cannot be shown, so dropping to a shell (outside the TUI record)." >&2
    vrt_drop_to_shell
    return 1
  fi
  while :; do
    choice=$(vrt_ui_choose --header="$(vrt_menu_header)" -- \
      "Status" "Peek session" "Stop session" "Audit log" \
      "Kill switches" "Drop to shell" "Quit")
    rc=$?
    if ((rc == 130)); then
      vrt_auth_cleanup
      return 130
    fi
    ((rc == 0)) || break
    case $choice in
      "Status") vrt_screen_status ;;
      "Peek session") vrt_screen_peek ;;
      "Stop session") vrt_screen_stop ;;
      "Audit log") vrt_screen_audit ;;
      "Kill switches") vrt_screen_kill_switches ;;
      "Drop to shell") vrt_screen_shell ;;
      *) break ;;
    esac
  done
  vrt_auth_cleanup
  return 0
}
