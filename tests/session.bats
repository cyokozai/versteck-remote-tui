#!/usr/bin/env bats
# セッション名の検査（docs/interface.md の文字種）

setup() {
  load test_helper
  common_setup
  load_libs
}

@test "通る名前" {
  local n
  for n in a claude-1 muse_2 agent.3 A9 "$(printf 'a%.0s' {1..64})"; do
    vrt_valid_session_name "$n" || { echo "通らなかった: $n"; return 1; }
  done
}

@test "通らない名前" {
  local n
  for n in "" "-x" "--all" "." ".." "../etc" "a b" "a;b" 'a$(id)' 'a`id`' "a/b" "あ" \
    $'a\nb' "$(printf 'a%.0s' {1..65})"; do
    if vrt_valid_session_name "$n"; then echo "通ってしまった: $n"; return 1; fi
  done
}
