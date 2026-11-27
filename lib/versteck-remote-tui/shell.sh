# shellcheck shell=bash
# シェルへ降りる（TUI が壊れても入れる逃げ道）

VRT_SHELL_NOTICE="シェルへ降ります。ここから先の操作は TUI を通らないため、TUI の記録の外です。
sudo の更新は止めます。ログインシェルでメニューが再び出ないよう VERSTECK_REMOTE_TUI_SKIP=1 を立てます。"

vrt_screen_shell() {
  gum style --border normal --padding "0 1" "$VRT_SHELL_NOTICE"
  vrt_ui_confirm "シェルへ降りますか？" || return 0
  vrt_drop_to_shell
}

# 確認なしで降りる（gum が無い・sudo に失敗したときの逃げ道にも使う）
vrt_drop_to_shell() {
  vrt_auth_cleanup
  export VERSTECK_REMOTE_TUI_SKIP=1
  vrt__exec_login_shell
}

vrt__exec_login_shell() {
  exec bash -l
}
