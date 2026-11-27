#!/usr/bin/env bats
# 入口の振り分け: 引数・端末の有無・SSH_ORIGINAL_COMMAND

setup() {
  load test_helper
  common_setup
}

@test "version は版とインターフェースの版を出して 0 で終わる" {
  run "$BIN" version
  [ "$status" -eq 0 ]
  [[ $output =~ ^versteck-remote-tui\ [0-9]+\.[0-9]+\.[0-9]+.*\(interface\ 1\)$ ]]
}

@test "help は使い方を出して 0 で終わる" {
  run "$BIN" help
  [ "$status" -eq 0 ]
  [[ $output == *status* ]]
  [[ $output == *audit* ]]
  [[ $output == *version* ]]
}

@test "知らない引数は使い方の誤りとして 2 で終わる" {
  run "$BIN" reboot
  [ "$status" -eq 2 ]
  [ -z "$(backend_log)" ]
}

@test "status に余計な引数があれば 2" {
  run "$BIN" status --json
  [ "$status" -eq 2 ]
}

@test "audit --limit に数字以外を渡すと 2" {
  run "$BIN" audit --limit abc
  [ "$status" -eq 2 ]
  [ -z "$(backend_log)" ]
}

@test "引数なしで端末でなければ、gum を呼ばずに使い方を返す" {
  run "$BIN" </dev/null
  [ "$status" -eq 0 ]
  [[ $output == *status* ]]
  [ -z "$(gum_log)" ]
}

@test "status は人が読む数行を返す" {
  run "$BIN" status
  [ "$status" -eq 0 ]
  [[ $output == *example-vm* ]]
  [[ $output == *claude-1* ]]
  [[ "$(backend_log)" == *"[status] [--json]"* ]]
}

@test "引数なしで端末なら TUI に入る" {
  load_libs
  vrt_is_tty() { return 0; }
  vrt_tui() { echo "TUI-STARTED"; }
  run vrt_main
  [ "$output" = "TUI-STARTED" ]
}

@test "端末でも引数があればテキストを返し、TUI に入らない" {
  load_libs
  vrt_is_tty() { return 0; }
  vrt_tui() { echo "TUI-STARTED"; }
  run vrt_main version
  [[ $output == versteck-remote-tui* ]]
}

@test "SSH_ORIGINAL_COMMAND=status は status のテキストを返す" {
  SSH_ORIGINAL_COMMAND=status run "$BIN"
  [ "$status" -eq 0 ]
  [[ $output == *example-vm* ]]
}

@test "SSH_ORIGINAL_COMMAND='audit --limit 5' はバックエンドに --limit 5 を渡す" {
  SSH_ORIGINAL_COMMAND="audit --limit 5" run "$BIN"
  [ "$status" -eq 0 ]
  [[ "$(backend_log)" == *"[audit] [--json] [--limit] [5]"* ]]
}

@test "SSH_ORIGINAL_COMMAND は引数より優先する" {
  SSH_ORIGINAL_COMMAND=version run "$BIN" status
  [[ $output == versteck-remote-tui* ]]
}

@test "SSH_ORIGINAL_COMMAND の注入の試みは 2 で拒み、何も実行しない" {
  local cmd
  for cmd in 'status; rm -rf /' 'status && id' 'status | sh' '$(touch /tmp/vrt-pwned)' \
    '`id`' $'status\nid' ' status' 'status ' 'audit --limit 99999' 'audit --limit 0' \
    'audit --limit 5; id' 'bash' 'peek claude-1' 'stop --all'; do
    : >"$FAKE_LOG_DIR/backend.log"
    SSH_ORIGINAL_COMMAND=$cmd run "$BIN"
    [ "$status" -eq 2 ] || { echo "許してしまった: $cmd"; return 1; }
    [[ $output == *許可されていない* ]]
    [ -z "$(backend_log)" ]
  done
  [ ! -e /tmp/vrt-pwned ]
}

@test "空の SSH_ORIGINAL_COMMAND は無いものとして扱う" {
  SSH_ORIGINAL_COMMAND= run "$BIN" version
  [ "$status" -eq 0 ]
  [[ $output == versteck-remote-tui* ]]
}

@test "help に余計な引数があれば 2" {
  run "$BIN" help foo
  [ "$status" -eq 2 ]
  run "$BIN" --help x
  [ "$status" -eq 2 ]
}

@test "VRT_LIBDIR を環境変数で渡しても、読み込む lib は変わらない" {
  mkdir -p "$BATS_TEST_TMPDIR/evil"
  printf 'vrt_main() { echo PWNED; }\n' >"$BATS_TEST_TMPDIR/evil/main.sh"
  VRT_LIBDIR="$BATS_TEST_TMPDIR/evil" run "$BIN" version
  [ "$status" -eq 0 ]
  [[ $output == versteck-remote-tui* ]]
  [[ $output != *PWNED* ]]
}
