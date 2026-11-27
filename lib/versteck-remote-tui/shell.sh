# shellcheck shell=bash
# シェルへ降りる（TUI が壊れても入れる逃げ道）

# 枠の中の各行は表示幅 74 以下（全角は 2）。枠の線と余白を足して 78 桁になり、80 桁の端末で崩れない
VRT_SHELL_NOTICE="シェルへ降ります。ここから先の操作は TUI を通らないため、
TUI の記録の外です。sudo の更新は止めます。
ログインシェルでメニューが再び出ないよう、
VERSTECK_REMOTE_TUI_SKIP=1 を立てます。"

vrt_screen_shell() {
  gum style --border normal --padding "0 1" -- "$VRT_SHELL_NOTICE"
  if ! vrt_ui_confirm "シェルへ降りますか？"; then
    vrt_ui_say "シェルへ降りませんでした。"
    return 0
  fi
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
