# 認証 B の起動: パスワードなしの sudo が通らない → sudo -v を 1 回 → メニューの上部に「認証: B」→ 終了
# 偽の sudo（tests/fixtures/bin/sudo）だけを PATH に足す。同じ場所の偽の gum は使わない。
# 偽の sudo は password の形では -v をパスワードを聞かずに通すので、パスワードの入力欄は録画に出ない。
Output docs/screens/auth-b.gif
Output docs/screens/auth-b.txt
Source docs/tapes/_settings.tape
Source docs/tapes/_env.tape

Hide
Type "mkdir -p /tmp/vrs-sudo && ln -sf /src/tests/fixtures/bin/sudo /tmp/vrs-sudo/sudo && export PATH=/tmp/vrs-sudo:$PATH VERSTECK_TUI_SUDO=auto FAKE_SUDO_MODE=password && clear"
Enter
Show

Type "versteck-remote-tui"
Enter
Sleep 2s
Down@300ms 6
Sleep 0.5s
Enter
Sleep 1s
