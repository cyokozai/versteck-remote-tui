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
