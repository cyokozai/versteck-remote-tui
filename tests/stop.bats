#!/usr/bin/env bats
# セッションを止める画面

setup() {
  load test_helper
  common_setup
  load_libs
}

assert_notice() {
  [[ $output == *"The human entrance keeps running"* ]]
  [[ $output == *"The only sure way to stop everything is to stop the VM"* ]]
}

@test "注意書きは定数に 2 つの文を持つ" {
  [[ $VRT_STOP_NOTICE == *"The human entrance keeps running"* ]]
  [[ $VRT_STOP_NOTICE == *"The only sure way to stop everything is to stop the VM"* ]]
}

@test "セッションが無くても注意書きを出す" {
  echo '{"sessions":[]}' >"$BATS_TEST_TMPDIR/empty.json"
  export FAKE_STATUS_JSON="$BATS_TEST_TMPDIR/empty.json"
  run vrt_screen_stop
  [ "$status" -eq 0 ]
  assert_notice
  [[ $output == *"No agent sessions are running"* ]]
}

@test "状態が取れなくても注意書きを出す" {
  export FAKE_BACKEND_FAIL=4
  run vrt_screen_stop
  assert_notice
  [[ $output == *"Could not get the information"* ]]
}

@test "確認で「いいえ」なら止めない" {
  gum_answers "claude-1" "no"
  run vrt_screen_stop
  [ "$status" -eq 0 ]
  assert_notice
  [[ "$(backend_log)" != *"[stop]"* ]]
  [[ $output == *"Nothing was stopped"* ]]
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
  [[ $output == *"Stopped."* ]]
}

@test "確認の問いにも注意書きを入れる" {
  gum_answers "claude-1" "no"
  run vrt_screen_stop
  grep '^gum \[confirm\]' "$FAKE_LOG_DIR/gum.log" | grep -q "The human entrance keeps running"
}

@test "すべて止めるも確認付き。「いいえ」なら止めない" {
  gum_answers "Stop all" "no"
  run vrt_screen_stop
  [[ "$(backend_log)" != *"[stop]"* ]]
}

@test "すべて止めるで「はい」なら stop --all" {
  gum_answers "Stop all" "yes"
  run vrt_screen_stop
  [[ "$(backend_log)" == *"[stop] [--all]"* ]]
}

@test "戻るを選べば何もしない" {
  gum_answers "Back"
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
  [[ $output == *"Target not found"* ]]
}

@test "検査を通らない名前はバックエンドに渡さず、弾いた件数を出す" {
  echo '{"sessions":[{"name":"bad;rm"},{"name":"claude-1"},{"agent":"noname"}]}' >"$BATS_TEST_TMPDIR/bad.json"
  export FAKE_STATUS_JSON="$BATS_TEST_TMPDIR/bad.json"
  gum_answers "Back"
  run vrt_screen_stop
  [ "$status" -eq 0 ]
  [[ $output == *"2 session(s) have a malformed name and are not listed"* ]]
  [[ $output != *"No agent sessions are running"* ]]
  grep '^gum \[choose\]' "$FAKE_LOG_DIR/gum.log" | grep -qF '[claude-1] [Stop all] [Back]'
  [[ "$(grep '^gum \[choose\]' "$FAKE_LOG_DIR/gum.log")" != *"bad;rm"* ]]
  [[ "$(backend_log)" != *"[stop]"* ]]
}

@test "一覧に出せる名前が 0 件でも「すべて止める」を選べる" {
  echo '{"sessions":[{"name":"bad;rm"}]}' >"$BATS_TEST_TMPDIR/bad.json"
  export FAKE_STATUS_JSON="$BATS_TEST_TMPDIR/bad.json"
  gum_answers "Stop all" "yes"
  run vrt_screen_stop
  [ "$status" -eq 0 ]
  [[ $output == *"1 session(s) have a malformed name"* ]]
  [[ "$(backend_log)" == *"[stop] [--all]"* ]]
  [[ "$(gum_log)" == *"Stop all 1 agent session(s)?"*"(includes 1 with a malformed name)"* ]]
}

@test "セッションが 0 件でも「すべて止める」を選べる" {
  echo '{"sessions":[]}' >"$BATS_TEST_TMPDIR/empty.json"
  export FAKE_STATUS_JSON="$BATS_TEST_TMPDIR/empty.json"
  gum_answers "Stop all" "yes"
  run vrt_screen_stop
  [ "$status" -eq 0 ]
  [[ $output == *"No agent sessions are running"* ]]
  [[ "$(backend_log)" == *"[stop] [--all]"* ]]
}

@test "status の JSON が壊れている・sessions が無いときは「ありません」ではなく取得の失敗と出す" {
  local j
  for j in 'not json' '{}' '{"sessions":"x"}'; do
    printf '%s\n' "$j" >"$BATS_TEST_TMPDIR/broken.json"
    export FAKE_STATUS_JSON="$BATS_TEST_TMPDIR/broken.json"
    : >"$FAKE_LOG_DIR/gum.log"
    run vrt_screen_stop
    [ "$status" -eq 0 ]
    assert_notice
    [[ $output == *"Could not get the session list"* ]] || { echo "文が無い: $j"; return 1; }
    [[ $output != *"No agent sessions are running"* ]]
    [ -z "$(grep '^gum \[choose\]' "$FAKE_LOG_DIR/gum.log")" ]
  done
}

@test "注意書きの各行は 80 桁の端末の枠に収まる" {
  assert_box_fits_80 "$VRT_STOP_NOTICE"
}

@test "「すべて止める」の問いの各行も 80 桁に収まる（件数が 4 桁でも）" {
  VRT_SESSION_TOTAL=0 VRT_SESSION_REJECTED=0
  assert_box_fits_80 "$(vrt_stop_all_question)"
  VRT_SESSION_TOTAL=9999 VRT_SESSION_REJECTED=9999
  assert_box_fits_80 "$(vrt_stop_all_question)"
  VRT_SESSION_TOTAL=9999 VRT_SESSION_REJECTED=0
  assert_box_fits_80 "$(vrt_stop_all_question)"
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
  [[ $output == *"Stopped."* ]]
  [[ $output == *"--all stopped"* ]]
  [[ $output != *"fake gum"* ]]
}

@test "確認は --default=false（既定は「いいえ」）と、はい・いいえの文言で聞く" {
  gum_answers "claude-1" "no"
  run vrt_screen_stop
  grep -qF 'gum [confirm] [--default=false] [--affirmative] [Yes] [--negative] [No] [--]' "$FAKE_LOG_DIR/gum.log"
}
