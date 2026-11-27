# 全部の操作スクリプトが Source で読む共通の設定（これ自体は録画しない。make screens は _ で始まるものを飛ばす）
Set Shell "bash"
Set FontFamily "Noto Sans Mono CJK JP"
Set FontSize 16
Set Width 945
Set Height 750
Set Padding 10
Set TypingSpeed 40ms
Set Theme "Builtin Dark"

Env PATH "/src/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Env VERSTECK_TUI_BACKEND "/src/tests/fixtures/fake-backend"
Env VERSTECK_TUI_SUDO "never"
Env FAKE_LOG_DIR "/tmp/vrs-log"
Env LANG "C.UTF-8"
