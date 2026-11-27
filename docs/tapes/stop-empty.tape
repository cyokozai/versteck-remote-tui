# セッションが 0 件のとき: セッションを止める → 注意書きと「ありません」→ メニューへ → Esc（終了）
Output docs/screens/stop-empty.gif
Output docs/screens/stop-empty.txt
Source docs/tapes/_settings.tape
Source docs/tapes/_env.tape

Hide
Type `jq '.sessions = []' tests/fixtures/status-ok.json >/tmp/vrs-status-empty.json && export FAKE_STATUS_JSON=/tmp/vrs-status-empty.json && clear`
Enter
Show

Type "versteck-remote-tui"
Enter
Sleep 1.5s
Down@300ms 2
Sleep 0.5s
Enter
Sleep 2s
Escape
Sleep 1s
