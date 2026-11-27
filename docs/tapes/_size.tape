# 共通の設定で端末が何桁×何行になるかを確かめる補助（録画しない。make screens は _ で始まるものを飛ばす）
# 使い方: docker run --rm -v "$PWD:/src" -w /src --entrypoint sh versteck-remote-tui-vhs:local \
#           -c 'vhs -q docs/tapes/_size.tape; grep -v "^ *$" /tmp/vrs-size.txt | tail -2'
# 期待: 「30 100」（30 行 × 100 桁）
Output "/tmp/vrs-size.txt"
Source docs/tapes/_settings.tape
Type "stty size"
Enter
Sleep 0.5s
