# shellcheck shell=bash
# shellcheck disable=SC2034  # 変数は各 .bats から使う
# テストの共通設定。偽の gum・sudo・バックエンドを PATH の先頭に置く。

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures"
BIN="$REPO_ROOT/bin/versteck-remote-tui"

common_setup() {
  REAL_PATH="$PATH"
  export REAL_PATH
  export PATH="$FIXTURES/bin:$PATH"
  export VERSTECK_TUI_BACKEND="$FIXTURES/fake-backend"
  export VERSTECK_TUI_SUDO=never
  export FAKE_LOG_DIR="$BATS_TEST_TMPDIR/log"
  mkdir -p "$FAKE_LOG_DIR"
  export FAKE_GUM_ANSWERS="$BATS_TEST_TMPDIR/gum-answers"
  : >"$FAKE_GUM_ANSWERS"
  export FAKE_STATUS_JSON="$FIXTURES/status-ok.json"
  export FAKE_AUDIT_JSONL="$FIXTURES/audit.jsonl"
  unset SSH_ORIGINAL_COMMAND VERSTECK_REMOTE_TUI_SKIP FAKE_BACKEND_FAIL FAKE_SUDO_MODE FAKE_SUDO_V_FAIL FAKE_SUDO_NOPASSWD FAKE_INTERFACE_JSON
}

# lib を読み込む（関数を直接試すとき）
load_libs() {
  local f
  for f in "$REPO_ROOT"/lib/versteck-remote-tui/*.sh; do
    # shellcheck source=/dev/null
    source "$f"
  done
}

# 偽の gum が返す答えを 1 行ずつ積む
gum_answers() {
  printf '%s\n' "$@" >>"$FAKE_GUM_ANSWERS"
}

backend_log() { cat "$FAKE_LOG_DIR/backend.log" 2>/dev/null || true; }
gum_log() { cat "$FAKE_LOG_DIR/gum.log" 2>/dev/null || true; }
sudo_log() { cat "$FAKE_LOG_DIR/sudo.log" 2>/dev/null || true; }
pager_out() { cat "$FAKE_LOG_DIR/pager.out" 2>/dev/null || true; }

# 偽の sudo に「同じ端末で先に sudo を使い、期限が残っている」状態を作る
sudo_ticket_valid() { : >"$FAKE_LOG_DIR/sudo.stamp"; }

# コマンド行が「sleep <秒>」のプロセスの PID を並べる（背景の更新が残っていないかを見る）
sleep_pids() {
  local secs=$1 f pid cmd
  for f in /proc/[0-9]*/cmdline; do
    pid=${f#/proc/}; pid=${pid%/cmdline}
    cmd=$(tr '\0' ' ' <"$f" 2>/dev/null) || continue
    [[ $cmd == "sleep $secs " ]] && echo "$pid"
  done
  return 0
}
