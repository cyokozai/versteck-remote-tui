#!/usr/bin/env bats
# セッションを止める画面

setup() {
  load test_helper
  common_setup
  load_libs
}

assert_notice() {
  [[ $output == *"人の入口は止まりません"* ]]
  [[ $output == *"確実に止まるのは VM を止めることです"* ]]
}

@test "注意書きは定数に 2 つの文を持つ" {
  [[ $VRT_STOP_NOTICE == *"人の入口は止まりません"* ]]
  [[ $VRT_STOP_NOTICE == *"確実に止まるのは VM を止めることです"* ]]
}

@test "セッションが無くても注意書きを出す" {
  echo '{"sessions":[]}' >"$BATS_TEST_TMPDIR/empty.json"
  export FAKE_STATUS_JSON="$BATS_TEST_TMPDIR/empty.json"
  run vrt_screen_stop
  [ "$status" -eq 0 ]
  assert_notice
  [[ $output == *"動いているエージェントのセッションはありません"* ]]
}

@test "状態が取れなくても注意書きを出す" {
  export FAKE_BACKEND_FAIL=4
  run vrt_screen_stop
  assert_notice
  [[ $output == *"取得できませんでした"* ]]
}

@test "確認で「いいえ」なら止めない" {
  gum_answers "claude-1" "no"
  run vrt_screen_stop
  [ "$status" -eq 0 ]
  assert_notice
  [[ "$(backend_log)" != *"[stop]"* ]]
  [[ $output == *"止めませんでした"* ]]
}

@test "確認を Esc で抜けても止めない" {
  gum_answers "claude-1"
  run vrt_screen_stop
  [[ "$(backend_log)" != *"[stop]"* ]]
}

@test "確認で「はい」なら選んだセッションだけを止める" {
  gum_answers "claude-1" "yes"
  run vrt_screen_stop
  [ "$status" -eq 0 ]
  assert_notice
  [[ "$(backend_log)" == *"[stop] [claude-1]"* ]]
  [[ "$(backend_log)" != *"[--all]"* ]]
  [[ $output == *"止めました"* ]]
}

@test "確認の問いにも注意書きを入れる" {
  gum_answers "claude-1" "no"
  run vrt_screen_stop
  grep '^gum \[confirm\]' "$FAKE_LOG_DIR/gum.log" | grep -q "人の入口は止まりません"
}

@test "すべて止めるも確認付き。「いいえ」なら止めない" {
  gum_answers "すべて止める" "no"
  run vrt_screen_stop
  [[ "$(backend_log)" != *"[stop]"* ]]
}

@test "すべて止めるで「はい」なら stop --all" {
  gum_answers "すべて止める" "yes"
  run vrt_screen_stop
  [[ "$(backend_log)" == *"[stop] [--all]"* ]]
}

@test "戻るを選べば何もしない" {
  gum_answers "戻る"
  run vrt_screen_stop
  [ "$status" -eq 0 ]
  [[ "$(backend_log)" != *"[stop]"* ]]
}

@test "止める途中でセッションが消えていたら（3）その旨を出す" {
  gum_answers "claude-1" "yes"
  # status は成功させ、stop だけ失敗させるため、偽物の上に一枚かぶせる
  cat >"$BATS_TEST_TMPDIR/backend" <<EOF
#!/usr/bin/env bash
[[ \$1 == stop ]] && exit 3
exec "$FIXTURES/fake-backend" "\$@"
EOF
  chmod +x "$BATS_TEST_TMPDIR/backend"
  export VERSTECK_TUI_BACKEND="$BATS_TEST_TMPDIR/backend"
  run vrt_screen_stop
  [[ $output == *"対象が見つかりません"* ]]
}

@test "検査を通らない名前はバックエンドに渡さない" {
  echo '{"sessions":[{"name":"bad;rm"}]}' >"$BATS_TEST_TMPDIR/bad.json"
  export FAKE_STATUS_JSON="$BATS_TEST_TMPDIR/bad.json"
  run vrt_screen_stop
  [[ $output == *"動いているエージェントのセッションはありません"* ]]
  [[ "$(backend_log)" != *"[stop]"* ]]
}

@test "止めた結果が - で始まっても、そのまま見せる（gum の引数と取り違えない）" {
  gum_answers "claude-1" "yes"
  cat >"$BATS_TEST_TMPDIR/backend" <<EOF
#!/usr/bin/env bash
if [[ \$1 == stop ]]; then printf -- '--all stopped\n- claude-1\n'; exit 0; fi
exec "$FIXTURES/fake-backend" "\$@"
EOF
  chmod +x "$BATS_TEST_TMPDIR/backend"
  export VERSTECK_TUI_BACKEND="$BATS_TEST_TMPDIR/backend"
  run vrt_screen_stop
  [ "$status" -eq 0 ]
  [[ $output == *"止めました"* ]]
  [[ $output == *"--all stopped"* ]]
  [[ $output != *"fake gum"* ]]
}

@test "確認は --default=false（既定は「いいえ」）と、はい・いいえの文言で聞く" {
  gum_answers "claude-1" "no"
  run vrt_screen_stop
  grep -qF 'gum [confirm] [--default=false] [--affirmative] [はい] [--negative] [いいえ] [--]' "$FAKE_LOG_DIR/gum.log"
}
