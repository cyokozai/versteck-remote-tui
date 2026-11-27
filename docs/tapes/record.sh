#!/usr/bin/env bash
# 操作スクリプトを VHS で流し、GIF を小さく作り直す。make screens がコンテナ（Dockerfile.vhs）の中で呼ぶ。
# 使い方: docs/tapes/record.sh docs/tapes/menu-status.tape [...]
#
# VHS の GIF は 25 コマ/秒で毎コマほぼ全面を描き直すため、1 本 5MB ほどになる（Set Framerate は GIF に効かない）。
# 同じ絵が続くコマを mpdecimate で落とし、32 色・ディザなしで書き直す。表示の時間は変わらない。
set -euo pipefail

for tape in "$@"; do
  name=$(basename "$tape" .tape)
  gif="docs/screens/$name.gif"
  echo "== $tape"
  mkdir -p /tmp/vrs-log
  vhs -q "$tape"
  ffmpeg -v error -y -i "$gif" \
    -filter_complex "fps=10,mpdecimate,split[a][b];[a]palettegen=max_colors=32:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" \
    -fps_mode vfr "/tmp/vrs-$name.gif"
  mv -f "/tmp/vrs-$name.gif" "$gif"
  printf '   %s %s bytes\n' "$gif" "$(stat -c %s "$gif")"
done
