#!/usr/bin/env bats
# 状態の一覧の整形（純粋な処理）と、バックエンドの終了コードごとの文言

setup() {
  load test_helper
  common_setup
  load_libs
}

@test "揃った JSON を人が読む行にする" {
  run vrt_format_status_text <"$FIXTURES/status-ok.json"
  [ "$status" -eq 0 ]
  [[ $output == *"ホスト: example-vm"* ]]
  [[ $output == *"取得時刻: 2026-11-27T01:02:03Z"* ]]
  [[ $output == *"人の入口: 稼働中 (active) sshd running"* ]]
  [[ $output == *"Tailscale: つながっている (connected) logged in"* ]]
  [[ $output == *"/ 42%"* ]]
  [[ $output == *"/var 93% 残りわずか"* ]]
  [[ $output == *"セッション: 2 件"* ]]
  [[ $output == *"claude-1 claude-code 2026-11-27T00:00:00Z"* ]]
}

@test "欠けた項目は「不明」と出し、失敗しない" {
  run vrt_format_status_text <<<'{}'
  [ "$status" -eq 0 ]
  [[ $output == *"ホスト: 不明"* ]]
  [[ $output == *"人の入口: 不明 (unknown)"* ]]
  [[ $output == *"Tailscale: 不明 (unknown)"* ]]
  [[ $output == *"ディスク: 不明"* ]]
  [[ $output == *"セッション: 不明"* ]]
}

@test "決まった値以外の state は unknown として扱う" {
  run vrt_format_status_text <<<'{"human_entrance":{"state":"exploded"},"tailscale":{"state":7},"sessions":[],"disks":[]}'
  [ "$status" -eq 0 ]
  [[ $output == *"人の入口: 不明 (unknown)"* ]]
  [[ $output == *"Tailscale: 不明 (unknown)"* ]]
  [[ $output == *"セッション: なし"* ]]
}

@test "failed と disconnected をそれぞれの日本語で出す" {
  run vrt_format_status_text <<<'{"human_entrance":{"state":"failed","detail":"x"},"tailscale":{"state":"disconnected"}}'
  [[ $output == *"人の入口: 失敗 (failed) x"* ]]
  [[ $output == *"Tailscale: 切れている (disconnected)"* ]]
}

@test "JSON でなければ失敗する" {
  run vrt_format_status_text <<<'not json'
  [ "$status" -ne 0 ]
  run vrt_format_status_text <<<'[1,2]'
  [ "$status" -ne 0 ]
}

@test "制御文字（端末の制御列）は出さない" {
  run vrt_format_status_text <<<'{"host":"ex\u001b[2Jample","human_entrance":{"state":"active","detail":"a\u0007b"}}'
  [ "$status" -eq 0 ]
  [[ $output != *$'\e'* ]]
  [[ $output != *$'\a'* ]]
}

@test "vrt_session_names は検査を通る名前だけを返す" {
  run vrt_session_names <<<'{"sessions":[{"name":"ok-1"},{"name":"bad;name"},{"name":"-x"},{"agent":"noname"},{"name":"ok.2"}]}'
  [ "$status" -eq 0 ]
  [ "$output" = $'ok-1\nok.2' ]
}

@test "status: バックエンドが 4 なら「取得できませんでした」で 4" {
  export FAKE_BACKEND_FAIL=4
  run vrt_run_text status
  [ "$status" -eq 4 ]
  [[ $output == *"取得できませんでした"* ]]
}

@test "status: バックエンドが 3 なら 3" {
  export FAKE_BACKEND_FAIL=3
  run vrt_run_text status
  [ "$status" -eq 3 ]
  [[ $output == *"対象が見つかりません"* ]]
}

@test "status: バックエンドが 2 なら版のずれを疑う文で 1" {
  export FAKE_BACKEND_FAIL=2
  run vrt_run_text status
  [ "$status" -eq 1 ]
  [[ $output == *"使い方の誤り"* ]]
}

@test "status: 予期しない終了コードは 1" {
  export FAKE_BACKEND_FAIL=9
  run vrt_run_text status
  [ "$status" -eq 1 ]
  [[ $output == *"予期しない失敗"*"9"* ]]
}

@test "status: バックエンドが JSON でないものを返したら 4" {
  export FAKE_STATUS_JSON="$FIXTURES/audit.jsonl"
  run vrt_run_text status
  [ "$status" -eq 4 ]
  [[ $output == *"読めません"* ]]
}

@test "vrt_backend_error_message は終了コードごとに文を変える" {
  [[ "$(vrt_backend_error_message 2)" == *"使い方の誤り"* ]]
  [[ "$(vrt_backend_error_message 3)" == *"対象が見つかりません"* ]]
  [[ "$(vrt_backend_error_message 4)" == *"取得できませんでした"* ]]
  [[ "$(vrt_backend_error_message 127)" == *"実行できません"* ]]
  [[ "$(vrt_backend_error_message 42)" == *"予期しない失敗"*"42"* ]]
}

@test "状態の画面: 整形した文を pager に渡し、再読み込みでもう一度取る" {
  gum_answers "再読み込み" "戻る"
  run vrt_screen_status
  [ "$status" -eq 0 ]
  [ "$(grep -c '\[status\] \[--json\]' "$FAKE_LOG_DIR/backend.log")" -eq 2 ]
  [[ "$(pager_out)" == *"ホスト: example-vm"* ]]
}

@test "状態の画面: 取得に失敗したら文言を出してメニューに戻る" {
  export FAKE_BACKEND_FAIL=4
  run vrt_screen_status
  [ "$status" -eq 0 ]
  [[ $output == *"取得できませんでした"* ]]
  [ -z "$(pager_out)" ]
}

@test "vrt_sanitize_text は C1 制御文字と向きを変える制御文字も落とし、日本語は残す" {
  local in out
  in=$(printf 'あ\xc2\x9b2Jい\xe2\x80\xaeう\xe2\x80\xaa\xe2\x80\x8e\xe2\x80\x8f\xe2\x81\xa6\xe2\x81\xa9\xd8\x9c\xc2\x80\xc2\x9fえ\xc2\xa0お')
  out=$(printf '%s' "$in" | vrt_sanitize_text)
  [ "$out" = $'あ2Jいうえ\xc2\xa0お' ]
}

@test "jq の clean は C1 制御文字と向きを変える制御文字を ? にする" {
  run jq -r "$VRT_JQ_CLEAN"' .[] | clean' <<<'["a\u009bb\u202ec", "\u0080\u009f\u061c\u200e\u200f\u202a\u2066\u2069", "日本語\u00a0ok"]'
  [ "${lines[0]}" = "a?b?c" ]
  [ "${lines[1]}" = "????????" ]
  [ "${lines[2]}" = $'日本語\xc2\xa0ok' ]
}

@test "状態の一覧の整形でも U+009B と U+202E を出さない" {
  run vrt_format_status_text <<<'{"host":"ex\u009b2Jample\u202e"}'
  [[ $output == *"ホスト: ex?2Jample?"* ]]
}

@test "vrt_session_total は sessions の件数を返し、配列でなければ・JSON でなければ失敗する" {
  run vrt_session_total <<<'{"sessions":[{"name":"ok-1"},{"name":"bad;name"},"x"]}'
  [ "$status" -eq 0 ]
  [ "$output" = 3 ]
  run vrt_session_total <<<'{"sessions":[]}'
  [ "$status" -eq 0 ]
  [ "$output" = 0 ]
  run vrt_session_total <<<'{}'
  [ "$status" -ne 0 ]
  run vrt_session_total <<<'{"sessions":"x"}'
  [ "$status" -ne 0 ]
  run vrt_session_total <<<'not json'
  [ "$status" -ne 0 ]
}
