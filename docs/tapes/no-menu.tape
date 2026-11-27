# メニューを出せないとき: バックエンドが見つからない → 文言 → 確認なしでシェルへ降りる
Output docs/screens/no-menu.gif
Output docs/screens/no-menu.txt
Source docs/tapes/_settings.tape
Source docs/tapes/_env.tape

Hide
Type "export VERSTECK_TUI_BACKEND=/usr/local/sbin/versteck-ctl && clear"
Enter
Show

Type "versteck-remote-tui"
Enter
Sleep 2s
Type "echo VERSTECK_REMOTE_TUI_SKIP=$VERSTECK_REMOTE_TUI_SKIP"
Enter
Sleep 1s
