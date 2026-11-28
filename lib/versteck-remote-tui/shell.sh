# shellcheck shell=bash
# シェルへ降りる（TUI が壊れても入れる逃げ道）

# 枠の中の各行は表示幅 74 以下（全角は 2）。枠の線と余白を足して 78 桁になり、80 桁の端末で崩れない
VRT_SHELL_NOTICE="Dropping to a shell. Commands from here on do not go through
the TUI, so they are outside the TUI record. The sudo refresh stops.
VERSTECK_REMOTE_TUI_SKIP=1 is set so that the menu does not
start again in the login shell."

vrt_screen_shell() {
  gum style --border normal --padding "0 1" -- "$VRT_SHELL_NOTICE"
  if ! vrt_ui_confirm "Drop to a shell?"; then
    vrt_ui_say "Did not drop to a shell."
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
