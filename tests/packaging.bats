#!/usr/bin/env bats
# 本物の gum の煙試験（非対話で動くものだけ）と、install・dist

setup() {
  load test_helper
  common_setup
}

real_gum() {
  PATH=$REAL_PATH command -v gum
}

@test "本物の gum format が Markdown を描ける" {
  local g
  g=$(real_gum) || skip "gum が無い"
  run "$g" format <<<"# 止め方の手順"
  [ "$status" -eq 0 ]
  [[ $output == *"止め方の手順"* ]]
}

@test "本物の gum style が文字を出せる" {
  local g
  g=$(real_gum) || skip "gum が無い"
  run "$g" style --bold --border normal --padding "0 1" "人の入口は止まりません"
  [ "$status" -eq 0 ]
  [[ $output == *"人の入口は止まりません"* ]]
}

@test "make install で置いたものが動く（bin から ../lib を見つける）" {
  run make -s -C "$REPO_ROOT" install DESTDIR="$BATS_TEST_TMPDIR/root" PREFIX=/usr
  [ "$status" -eq 0 ]
  [ -x "$BATS_TEST_TMPDIR/root/usr/bin/versteck-remote-tui" ]
  [ -r "$BATS_TEST_TMPDIR/root/usr/share/doc/versteck-remote-tui/interface.md" ]
  run "$BATS_TEST_TMPDIR/root/usr/bin/versteck-remote-tui" version
  [ "$status" -eq 0 ]
  [[ $output == versteck-remote-tui* ]]
}

@test "make dist は決まった名前の tar.gz と SHA256SUMS を作り、版を書き込む" {
  local d="$BATS_TEST_TMPDIR/dist"
  run make -s -C "$REPO_ROOT" dist VERSION=1.2.3 DIST_DIR="$d"
  [ "$status" -eq 0 ]
  [ -f "$d/versteck-remote-tui-v1.2.3.tar.gz" ]
  (cd "$d" && sha256sum -c SHA256SUMS)
  run tar -tzf "$d/versteck-remote-tui-v1.2.3.tar.gz"
  [[ $output == *"versteck-remote-tui-v1.2.3/bin/versteck-remote-tui"* ]]
  [[ $output == *"versteck-remote-tui-v1.2.3/lib/versteck-remote-tui/main.sh"* ]]
  [[ $output == *"versteck-remote-tui-v1.2.3/docs/interface.md"* ]]
  [[ $output == *"versteck-remote-tui-v1.2.3/LICENSE"* ]]
  [[ $output == *"versteck-remote-tui-v1.2.3/README.md"* ]]
  [[ $output != *tests/* ]]
  mkdir -p "$BATS_TEST_TMPDIR/x"
  tar -xzf "$d/versteck-remote-tui-v1.2.3.tar.gz" -C "$BATS_TEST_TMPDIR/x"
  run "$BATS_TEST_TMPDIR/x/versteck-remote-tui-v1.2.3/bin/versteck-remote-tui" version
  [ "$output" = "versteck-remote-tui 1.2.3 (interface 1)" ]
}

@test "make dist は v 付きや semver でない VERSION を拒む" {
  run make -s -C "$REPO_ROOT" dist VERSION=v1.2.3 DIST_DIR="$BATS_TEST_TMPDIR/dist"
  [ "$status" -ne 0 ]
  run make -s -C "$REPO_ROOT" dist VERSION=1.2 DIST_DIR="$BATS_TEST_TMPDIR/dist"
  [ "$status" -ne 0 ]
}

@test "本物の gum style の枠は 80 桁に収まる（止める画面・シェルへ降りる画面の注意書き）" {
  local g l
  g=$(real_gum) || skip "gum が無い"
  load_libs
  local text
  for text in "$VRT_STOP_NOTICE" "$VRT_SHELL_NOTICE"; do
    while IFS= read -r l; do
      (($(display_width "$l") <= 80)) || { echo "80 桁を超えた: $l"; return 1; }
    done < <("$g" style --border normal --padding "0 1" -- "$text")
  done
}
