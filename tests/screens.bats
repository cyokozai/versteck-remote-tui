#!/usr/bin/env bats
# 覗く・止め方の手順・シェルへ降りる・メニュー

setup() {
  load test_helper
  common_setup
  load_libs
}

@test "覗く: 選んだセッションの画面を pager で見せ、再読み込みで取り直す" {
  gum_answers "claude-1" "再読み込み" "戻る"
  run vrt_screen_peek
  [ "$status" -eq 0 ]
  [ "$(grep -c '\[peek\] \[claude-1\]' "$FAKE_LOG_DIR/backend.log")" -eq 2 ]
  [[ "$(pager_out)" == *"screen of claude-1"* ]]
  [[ "$(pager_out)" == *"読み取り専用"* ]]
}

@test "覗く: tmux には触らない（バックエンドの peek だけを呼ぶ）" {
  gum_answers "muse-1" "戻る"
  run vrt_screen_peek
  [[ "$(backend_log)" == *"[peek] [muse-1]"* ]]
  [[ "$(backend_log)" != *attach* ]]
}

@test "覗く: 画面の文字の制御列は落とす" {
  cat >"$BATS_TEST_TMPDIR/backend" <<EOF
#!/usr/bin/env bash
if [[ \$1 == peek ]]; then printf 'a\033]0;title\007b\033[31mred\n'; exit 0; fi
exec "$FIXTURES/fake-backend" "\$@"
EOF
  chmod +x "$BATS_TEST_TMPDIR/backend"
  export VERSTECK_TUI_BACKEND="$BATS_TEST_TMPDIR/backend"
  gum_answers "claude-1" "戻る"
  run vrt_screen_peek
  [[ "$(pager_out)" != *$'\e'* ]]
  [[ "$(pager_out)" != *$'\a'* ]]
}

@test "覗く: セッションが消えていたら（3）その旨を出す" {
  cat >"$BATS_TEST_TMPDIR/backend" <<EOF
#!/usr/bin/env bash
[[ \$1 == peek ]] && exit 3
exec "$FIXTURES/fake-backend" "\$@"
EOF
  chmod +x "$BATS_TEST_TMPDIR/backend"
  export VERSTECK_TUI_BACKEND="$BATS_TEST_TMPDIR/backend"
  gum_answers "claude-1"
  run vrt_screen_peek
  [[ $output == *"対象が見つかりません"* ]]
}

@test "止め方の手順: バックエンドの Markdown を gum format に通して見せる" {
  gum_answers
  run vrt_screen_kill_switches
  [ "$status" -eq 0 ]
  [[ "$(backend_log)" == *"[kill-switches]"* ]]
  [[ "$(gum_log)" == *"gum [format]"* ]]
  [[ "$(pager_out)" == *"VM を止める"* ]]
}

@test "止め方の手順: 取得に失敗したら文言を出す" {
  export FAKE_BACKEND_FAIL=4
  run vrt_screen_kill_switches
  [[ $output == *"取得できませんでした"* ]]
}

@test "シェルへ降りる: 記録の外であることを書き、目印を立て、更新を止めてから exec する" {
  vrt__exec_login_shell() { echo "SHELL-EXEC skip=$VERSTECK_REMOTE_TUI_SKIP keepalive=${VRT_KEEPALIVE_PID:-none}"; }
  VRT_KEEPALIVE_PID=""
  gum_answers "yes"
  run vrt_screen_shell
  [[ $output == *"TUI の記録の外"* ]]
  [[ $output == *"SHELL-EXEC skip=1 keepalive=none"* ]]
}

@test "シェルへ降りる: 「いいえ」なら降りない" {
  vrt__exec_login_shell() { echo "SHELL-EXEC"; }
  gum_answers "no"
  run vrt_screen_shell
  [[ $output != *SHELL-EXEC* ]]
}

@test "メニュー: 上部に認証の方式を出し、終了で 0" {
  vrt_is_tty() { return 0; }
  gum_answers "終了"
  run vrt_main
  [ "$status" -eq 0 ]
  grep '^gum \[choose\]' "$FAKE_LOG_DIR/gum.log" | head -1 | grep -q "認証: sudo なし"
}

@test "メニュー: 6 つの画面を並べ、Ansible の再実行と PR の一覧は無い" {
  vrt_is_tty() { return 0; }
  gum_answers "終了"
  run vrt_main
  local menu
  menu=$(gum_log)
  local item
  for item in "状態の一覧" "セッションを覗く" "セッションを止める" "監査ログ" "止め方の手順" "シェルへ降りる"; do
    [[ $menu == *"[$item]"* ]] || { echo "無い: $item"; return 1; }
  done
  [[ $menu != *Ansible* ]]
  [[ $menu != *PR* ]]
}

@test "メニュー: 選んだ画面に入り、戻ってくる" {
  vrt_is_tty() { return 0; }
  gum_answers "状態の一覧" "戻る" "終了"
  run vrt_main
  [ "$status" -eq 0 ]
  [[ "$(pager_out)" == *"ホスト: example-vm"* ]]
}

@test "メニュー: gum が無ければ分かる文を出してシェルへ降りる" {
  vrt_is_tty() { return 0; }
  vrt__exec_login_shell() { echo "SHELL-EXEC"; }
  vrt_have_command() { [[ $1 != gum ]]; }
  run vrt_main
  [[ $output == *"gum が見つかりません"* ]]
  [[ $output == *SHELL-EXEC* ]]
}
