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

# 端末での表示幅（全角・東アジアの広い文字を 2、ほかを 1 と数える）。ロケールに頼らず UTF-8 として数える
display_width() {
  LC_ALL=C.UTF-8 bash -c '
    s=$1 w=0
    for ((i = 0; i < ${#s}; i++)); do
      printf -v cp "%d" "'"'"'${s:i:1}"
      if ((cp >= 0x1100 && cp <= 0x115F || cp >= 0x2E80 && cp <= 0xA4CF || cp >= 0xAC00 && cp <= 0xD7A3 ||
        cp >= 0xF900 && cp <= 0xFAFF || cp >= 0xFE30 && cp <= 0xFE4F || cp >= 0xFF00 && cp <= 0xFF60 ||
        cp >= 0xFFE0 && cp <= 0xFFE6 || cp >= 0x1F300 && cp <= 0x1FAFF || cp >= 0x20000 && cp <= 0x3FFFD)); then
        w=$((w + 2))
      else
        w=$((w + 1))
      fi
    done
    echo "$w"' _ "$1"
}

# 枠（gum style --border normal --padding "0 1"）に入れる文言の各行が、80 桁の端末で崩れない幅か。
# 枠の左右の線と余白で 4 桁を使うので、各行は 74 以下
assert_box_fits_80() {
  local text=$1 l w
  while IFS= read -r l; do
    w=$(display_width "$l")
    ((w <= 74)) || { echo "幅 $w > 74: $l"; return 1; }
  done <<<"$text"
}

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
