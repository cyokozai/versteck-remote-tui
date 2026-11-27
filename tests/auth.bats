#!/usr/bin/env bats
# 認証の方式 A（sudoers でパスワードなし）と B（sudo -v を 1 回・背景で更新）

setup() {
  load test_helper
  common_setup
  export VERSTECK_TUI_SUDO=auto
  export VERSTECK_TUI_SUDO_REFRESH=37
  load_libs
}

teardown() {
  # 念のため: テストが残した更新のプロセスを止める
  local p
  for p in $(sleep_pids 37); do kill "$p" 2>/dev/null || true; done
}

@test "VERSTECK_TUI_SUDO=never なら sudo を使わない" {
  export VERSTECK_TUI_SUDO=never
  vrt_auth_init tui
  [ "$VRT_AUTH_MODE" = none ]
  vrt_backend status --json >/dev/null
  [ -z "$(sudo_log)" ]
  [[ "$(backend_log)" == *"[status] [--json]"* ]]
}

@test "sudo -n が通れば A。パスワードは聞かない" {
  export FAKE_SUDO_MODE=nopasswd
  vrt_auth_init tui
  [ "$VRT_AUTH_MODE" = A ]
  [[ "$(sudo_log)" == *"[-k] [-n] [--] [$VERSTECK_TUI_BACKEND] [interface-version]"* ]]
  [[ "$(sudo_log)" != *"[-v]"* ]]
  [ -z "$VRT_KEEPALIVE_PID" ]
}

@test "同じ端末に sudo の期限が残っていても、判定は期限を無視するので B になり更新が始まる" {
  export FAKE_SUDO_MODE=password
  sudo_ticket_valid
  vrt_auth_init tui
  [ "$VRT_AUTH_MODE" = B ]
  [ -n "$VRT_KEEPALIVE_PID" ]
  [[ "$(sudo_log)" == *"[-k] [-n] [--] [$VERSTECK_TUI_BACKEND] [interface-version]"* ]]
  vrt_auth_cleanup
}

@test "sudoers の許可一覧に interface-version があれば、期限が無くても A" {
  export FAKE_SUDO_MODE=password FAKE_SUDO_NOPASSWD="$VERSTECK_TUI_BACKEND interface-version"
  vrt_auth_init tui
  [ "$VRT_AUTH_MODE" = A ]
  [[ "$(sudo_log)" != *"[-v]"* ]]
  [ -z "$VRT_KEEPALIVE_PID" ]
}

@test "A ではバックエンドを sudo -n で呼ぶ" {
  export FAKE_SUDO_MODE=nopasswd
  vrt_auth_init tui
  : >"$FAKE_LOG_DIR/sudo.log"
  vrt_backend status --json >/dev/null
  [ "$(sudo_log)" = "sudo [-n] [--] [$VERSTECK_TUI_BACKEND] [status] [--json]" ]
}

@test "sudo -n が通らなければ B。sudo -v を 1 回だけ呼び、以後は sudo -n" {
  export FAKE_SUDO_MODE=password
  vrt_auth_init tui
  [ "$VRT_AUTH_MODE" = B ]
  [ "$(grep -c '^sudo \[-v\]$' "$FAKE_LOG_DIR/sudo.log")" -eq 1 ]
  : >"$FAKE_LOG_DIR/sudo.log"
  vrt_backend status --json >/dev/null
  [ "$(sudo_log)" = "sudo [-n] [--] [$VERSTECK_TUI_BACKEND] [status] [--json]" ]
  vrt_auth_cleanup
}

@test "B の背景の更新は後始末で止まり、sleep の子も残らない" {
  export FAKE_SUDO_MODE=password
  vrt_auth_init tui
  [ -n "$VRT_KEEPALIVE_PID" ]
  local pid=$VRT_KEEPALIVE_PID
  kill -0 "$pid"
  # sleep の子が立ち上がるのを待つ
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do [ -n "$(sleep_pids 37)" ] && break; sleep 0.1; done
  [ -n "$(sleep_pids 37)" ]
  vrt_auth_cleanup
  [ -z "$VRT_KEEPALIVE_PID" ]
  ! kill -0 "$pid" 2>/dev/null
  for i in 1 2 3 4 5 6 7 8 9 10; do [ -z "$(sleep_pids 37)" ] && break; sleep 0.1; done
  [ -z "$(sleep_pids 37)" ]
}

@test "B の背景の更新は sudo -n -v を呼ぶ" {
  export FAKE_SUDO_MODE=password VERSTECK_TUI_SUDO_REFRESH=1
  vrt_auth_init tui
  sleep 1.5
  vrt_auth_cleanup
  [[ "$(sudo_log)" == *"sudo [-n] [-v]"* ]]
}

@test "TUI を抜けると背景の更新は残らない（EXIT の trap）" {
  export FAKE_SUDO_MODE=password
  run bash -c '
    for f in "$1"/lib/versteck-remote-tui/*.sh; do source "$f"; done
    vrt_is_tty() { return 0; }
    vrt_main' _ "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$(gum_log)" == *"認証: B"* ]]
  sleep 0.3
  [ -z "$(sleep_pids 37)" ]
}

@test "sudo -v に失敗したら分かる文を出し、シェルへ降りる道を残す" {
  export FAKE_SUDO_MODE=password FAKE_SUDO_V_FAIL=1
  vrt_is_tty() { return 0; }
  vrt__exec_login_shell() { echo "SHELL-EXEC skip=$VERSTECK_REMOTE_TUI_SKIP"; }
  run vrt_main
  [[ $output == *"sudo の確認に失敗しました"* ]]
  [[ $output == *"SHELL-EXEC skip=1"* ]]
}

@test "端末でないテキストの呼び出しでは sudo -v を呼ばずに失敗する" {
  export FAKE_SUDO_MODE=password
  run vrt_run_text status </dev/null
  [ "$status" -eq 4 ]
  [[ $output == *"パスワードなしの sudo"* ]]
  [[ "$(sudo_log)" != *"[-v]"* ]]
}

@test "インターフェースの版が違えば分かる文で失敗する" {
  export VERSTECK_TUI_SUDO=never FAKE_INTERFACE_JSON='{"interface":2}'
  run vrt_auth_init tui
  [ "$status" -ne 0 ]
  run vrt_run_text status
  [ "$status" -eq 4 ]
  [[ $output == *"インターフェースの版が合いません"* ]]
}

@test "バックエンドが無ければ、パスワードを聞く前にその旨を出す" {
  export VERSTECK_TUI_BACKEND=/nonexistent/versteck-ctl
  run vrt_run_text status
  [ "$status" -eq 4 ]
  [[ $output == *"バックエンドが見つかりません"* ]]
  [ -z "$(sudo_log)" ]
}

@test "VERSTECK_TUI_SUDO の値が不正なら 2" {
  export VERSTECK_TUI_SUDO=sometimes
  run vrt_run_text status
  [ "$status" -eq 2 ]
  [[ $output == *VERSTECK_TUI_SUDO* ]]
}
