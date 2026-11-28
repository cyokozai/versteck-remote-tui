#!/usr/bin/env bats
# 監査ログ: 並び・失敗だけ・エージェント名の絞り込み（jq で TUI 側が行う）

setup() {
  load test_helper
  common_setup
  load_libs
}

@test "新しい順に並べ、JSON でない行は飛ばす" {
  result=$(vrt_audit_filter <"$FIXTURES/audit.jsonl" | jq -r '.[].time' | paste -sd,)
  [ "$result" = "2026-11-27T00:40:00Z,2026-11-27T00:30:00Z,2026-11-27T00:20:00Z,2026-11-27T00:10:00Z" ]
}

@test "失敗だけ: ok 以外（denied と error）を残す" {
  result=$(vrt_audit_filter --failed <"$FIXTURES/audit.jsonl" | jq -r '.[].result' | paste -sd,)
  [ "$result" = "denied,error" ]
}

@test "エージェント名で絞る" {
  result=$(vrt_audit_filter --agent muse <"$FIXTURES/audit.jsonl" | jq -r '.[].command' | paste -sd,)
  [ "$result" = "ls,rm -rf /tmp/x" ]
}

@test "失敗だけとエージェント名を重ねられる" {
  result=$(vrt_audit_filter --failed --agent claude-code <"$FIXTURES/audit.jsonl" | jq -r '.[].command' | paste -sd,)
  [ "$result" = "make test" ]
}

@test "引用符を含むエージェント名でも jq の式は壊れない" {
  run vrt_audit_filter --agent '") or true or ("' <"$FIXTURES/audit.jsonl"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "エージェント名の一覧は重複なしで並ぶ" {
  run vrt_audit_agents <"$FIXTURES/audit.jsonl"
  [ "$output" = $'claude-code\nmuse' ]
}

@test "整形した行は 時刻・結果・エージェント・コマンド・詳細 を持ち、制御文字を出さない" {
  run bash -c 'for f in "$1"/lib/versteck-remote-tui/*.sh; do source "$f"; done
    printf "%s\n" "{\"time\":\"t1\",\"agent\":\"a\",\"command\":\"c\\u001b[2J\",\"result\":\"ok\",\"detail\":\"d\"}" | vrt_audit_filter | vrt_audit_format' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ $output == "t1  ok  a  c"*"  d" ]]
  [[ $output != *$'\e'* ]]
}

@test "監査ログの画面: 失敗だけを選ぶと pager に失敗の行だけが出る" {
  gum_answers "Failures only" "Back"
  run vrt_screen_audit
  [ "$status" -eq 0 ]
  [[ "$(backend_log)" == *"[audit] [--json] [--limit] [200]"* ]]
  [[ "$(pager_out)" == *denied* ]]
  [[ "$(pager_out)" == *error* ]]
  [[ "$(pager_out)" != *"  ok  "* ]]
}

@test "監査ログの画面: エージェント名を gum filter で選んで絞る" {
  gum_answers "Filter by agent" "muse" "Back"
  run vrt_screen_audit
  [[ "$(gum_log)" == *"gum [filter]"* ]]
  [[ "$(pager_out)" == *"rm -rf /tmp/x"* ]]
  [[ "$(pager_out)" != *"make test"* ]]
}

@test "監査ログの画面: 該当なしならその旨を出す" {
  printf '%s\n' '{"time":"2026-11-27T00:10:00Z","agent":"muse","command":"ls","result":"ok"}' >"$BATS_TEST_TMPDIR/ok.jsonl"
  export FAKE_AUDIT_JSONL="$BATS_TEST_TMPDIR/ok.jsonl"
  gum_answers "Failures only" "Back"
  run vrt_screen_audit
  [[ "$(pager_out)" == *"No matching entries"* ]]
}

@test "監査ログの画面: 取得に失敗したら文言を出して戻る" {
  export FAKE_BACKEND_FAIL=4
  run vrt_screen_audit
  [[ $output == *"Could not get the information"* ]]
  [ -z "$(pager_out)" ]
}

@test "テキストの audit は新しい順の行を返す" {
  run vrt_run_text audit --limit 2
  [ "$status" -eq 0 ]
  [[ "$(backend_log)" == *"[audit] [--json] [--limit] [2]"* ]]
  [[ "${lines[0]}" == 2026-11-27T00:40:00Z* ]]
}

@test "time の無い記録は新しい順の末尾に回す" {
  result=$(printf '%s\n' '{"time":"2026-11-27T00:10:00Z","command":"a"}' '{"command":"no-time"}' \
    '{"time":"2026-11-27T00:20:00Z","command":"b"}' '{"time":7,"command":"num-time"}' |
    vrt_audit_filter | jq -r '.[].command' | paste -sd,)
  [ "$result" = "b,a,no-time,num-time" ] || [ "$result" = "b,a,num-time,no-time" ]
}

@test "エージェント名の絞り込みは、選択肢に出した名前（制御文字を ? にしたもの）と比べる" {
  local data='{"time":"t1","agent":"ev\u001bil","command":"x","result":"ok"}'
  run vrt_audit_agents <<<"$data"
  [ "$output" = "ev?il" ]
  result=$(vrt_audit_filter --agent "ev?il" <<<"$data" | jq -r '.[].command' | paste -sd,)
  [ "$result" = "x" ]
}

@test "監査ログの画面: 制御文字を含むエージェント名を選んでも、その記録が出る" {
  printf '%s\n' '{"time":"t1","agent":"ev\u001bil","command":"evil-cmd","result":"ok"}' \
    '{"time":"t2","agent":"muse","command":"ls","result":"ok"}' >"$BATS_TEST_TMPDIR/a.jsonl"
  export FAKE_AUDIT_JSONL="$BATS_TEST_TMPDIR/a.jsonl"
  gum_answers "Filter by agent" "ev?il" "Back"
  run vrt_screen_audit
  [[ "$(pager_out)" == *"evil-cmd"* ]]
  [[ "$(pager_out)" != *"  ls"* ]]
}
