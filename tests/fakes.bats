#!/usr/bin/env bats
# 偽の gum・sudo そのものの検査。偽物が甘いと、本物で落ちる呼び出しがテストを通ってしまう

setup() {
  load test_helper
  common_setup
}

@test "偽の gum: -- より前の位置引数は 98 で落とす（- で始まる文字列も）" {
  run gum style "止めました。"
  [ "$status" -eq 98 ]
  run gum style --foreground 1 "-x"
  [ "$status" -eq 98 ]
  run gum style --foreground 1 -- "-x" "--all"
  [ "$status" -eq 0 ]
  [ "$output" = $'-x\n--all' ]
}

@test "偽の gum: 知らないフラグとサブコマンドは 99" {
  run gum style --nope -- x
  [ "$status" -eq 99 ]
  run gum input -- x
  [ "$status" -eq 99 ]
}

@test "偽の gum: choose の答えは選択肢の中に無ければ 97" {
  gum_answers "c"
  run gum choose --header h -- a b
  [ "$status" -eq 97 ]
  gum_answers "b"
  run gum choose --header h -- a b
  [ "$status" -eq 0 ]
  [ "$output" = b ]
}

@test "偽の gum: filter は標準入力の行を選択肢にし、その中に無い答えは 97" {
  gum_answers "nobody" "muse"
  run gum filter --placeholder p <<<$'claude-code\nmuse'
  [ "$status" -eq 97 ]
  run gum filter --placeholder p <<<$'claude-code\nmuse'
  [ "$status" -eq 0 ]
  [ "$output" = muse ]
}

@test "偽の gum: confirm は --default=false の形だけを受け、--default false は落とす" {
  gum_answers "yes" "yes"
  run gum confirm --default=false --affirmative Yes --negative No -- "問い"
  [ "$status" -eq 0 ]
  run gum confirm --default false -- "問い"
  [ "$status" -eq 98 ]
}

@test "偽の gum: <esc> は choose で nothing selected と 1、confirm で 1。<ctrl-c> と答え切れは 130" {
  gum_answers "<esc>" "<esc>" "<ctrl-c>"
  run gum choose -- a b
  [ "$status" -eq 1 ]
  [[ $output == *"nothing selected"* ]]
  run gum confirm -- q
  [ "$status" -eq 1 ]
  run gum choose -- a b
  [ "$status" -eq 130 ]
  run gum choose -- a b
  [ "$status" -eq 130 ]
}

@test "偽の sudo: 期限が残っていれば -n で通り、-k を付けるとその 1 回だけ無視する" {
  export FAKE_SUDO_MODE=password
  run sudo -n -- true
  [ "$status" -eq 1 ]
  sudo_ticket_valid
  run sudo -n -- true
  [ "$status" -eq 0 ]
  run sudo -k -n -- true
  [ "$status" -eq 1 ]
  # -k をコマンドと一緒に付けても期限は消えない
  run sudo -n -- true
  [ "$status" -eq 0 ]
}

@test "偽の sudo: 許可一覧のコマンド行だけが期限なしで通る" {
  export FAKE_SUDO_MODE=password FAKE_SUDO_NOPASSWD=$'/bin/echo a\n/bin/echo b c'
  run sudo -k -n -- /bin/echo a
  [ "$status" -eq 0 ]
  run sudo -k -n -- /bin/echo b c
  [ "$status" -eq 0 ]
  run sudo -k -n -- /bin/echo b
  [ "$status" -eq 1 ]
}
