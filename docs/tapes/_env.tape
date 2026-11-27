# 全部の操作スクリプトが _settings.tape の後に Source で読む環境変数（これ自体は録画しない）
# 偽のバックエンド（tests/fixtures/fake-backend）を sudo なしで使う。リポジトリはコンテナの /src に置く。
Env PATH "/src/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Env VERSTECK_TUI_BACKEND "/src/tests/fixtures/fake-backend"
Env VERSTECK_TUI_SUDO "never"
Env FAKE_LOG_DIR "/tmp/vrs-log"
Env LANG "C.UTF-8"
