#!/usr/bin/env bats
# 画面の設計（docs/screens.md）と録画（docs/tapes → docs/screens）が、実装とずれていないかを見る。
# 録画そのものは make screens（VHS のコンテナ）で作る。ここでは作られたテキストと文書を読むだけ。

load test_helper

setup() {
  DOC="$REPO_ROOT/docs/screens.md"
  TAPES="$REPO_ROOT/docs/tapes"
  SHOTS="$REPO_ROOT/docs/screens"
}

tapes() {
  local t
  for t in "$TAPES"/*.tape; do
    [[ $(basename "$t") == _* ]] && continue
    basename "$t" .tape
  done
}

@test "操作スクリプトが 1 本以上あり、どれも同じ名前の GIF とテキストを docs/screens に出す" {
  local n=0 name
  while read -r name; do
    n=$((n + 1))
    grep -qx "Output docs/screens/$name.gif" "$TAPES/$name.tape"
    grep -qx "Output docs/screens/$name.txt" "$TAPES/$name.tape"
    grep -qx "Source docs/tapes/_settings.tape" "$TAPES/$name.tape"
  done < <(tapes)
  ((n > 0))
}

@test "録画の GIF とテキストがそろっている（make screens の実行済み）" {
  local name
  while read -r name; do
    [ -s "$SHOTS/$name.gif" ]
    [ -s "$SHOTS/$name.txt" ]
  done < <(tapes)
}

@test "docs/screens.md が各操作スクリプトの GIF とテキストへリンクしている" {
  local name
  while read -r name; do
    grep -qF "(screens/$name.gif)" "$DOC"
    grep -qF "(screens/$name.txt)" "$DOC"
    grep -qF "(tapes/$name.tape)" "$DOC"
  done < <(tapes)
}

@test "メニューの項目（実装の tui.sh）が録画と docs/screens.md の両方に出る" {
  local item
  for item in "状態の一覧" "セッションを覗く" "セッションを止める" "監査ログ" "止め方の手順" "シェルへ降りる" "終了"; do
    grep -qF "\"$item\"" "$REPO_ROOT/lib/versteck-remote-tui/tui.sh"
    grep -qE "^[> ] $item\$" "$SHOTS/menu-status.txt"
    grep -qE "^[> ] $item\$" "$DOC"
  done
}

@test "止める画面の注意書き（実装の VRT_STOP_NOTICE）が録画と docs/screens.md に出る" {
  load_libs
  local line
  while IFS= read -r line; do
    grep -qF "$line" "$SHOTS/stop-one.txt"
    grep -qF "$line" "$DOC"
  done <<<"$VRT_STOP_NOTICE"
}

@test "シェルへ降りる画面の注意書き（実装の VRT_SHELL_NOTICE）が録画と docs/screens.md に出る" {
  load_libs
  local line
  while IFS= read -r line; do
    grep -qF "$line" "$SHOTS/shell.txt"
    grep -qF "$line" "$DOC"
  done <<<"$VRT_SHELL_NOTICE"
}

@test "認証 B の表示が録画と docs/screens.md に出る" {
  grep -qF "認証: B（sudo のパスワード・60 秒ごとに更新）" "$SHOTS/auth-b.txt"
  grep -qF "認証: B（sudo のパスワード・60 秒ごとに更新）" "$DOC"
  grep -qF "認証: A（鍵のログインのみ・sudoers で許可）" "$DOC"
}

@test "docs/screens.md の遷移の地図は mermaid を使わない" {
  run grep -c '```mermaid' "$DOC"
  [ "$output" = 0 ]
}
