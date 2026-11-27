# メニュー → シェルへ降りる → 確認で「いいえ」（既定）→ メニュー → もう一度 → ← して「はい」→ ログインシェル
Output docs/screens/shell.gif
Output docs/screens/shell.txt
Source docs/tapes/_settings.tape
Source docs/tapes/_env.tape

Hide
Type "clear"
Enter
Show

Type "versteck-remote-tui"
Enter
Sleep 1.5s
Down@300ms 5
Sleep 0.5s
Enter
Sleep 1.5s
Enter
Sleep 1.5s
Down@300ms 5
Sleep 0.5s
Enter
Sleep 1.5s
Left
Sleep 0.5s
Enter
Sleep 1.5s
Type "echo VERSTECK_REMOTE_TUI_SKIP=$VERSTECK_REMOTE_TUI_SKIP"
Enter
Sleep 1s
