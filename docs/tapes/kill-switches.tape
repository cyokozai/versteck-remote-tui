# メニュー → 止め方の手順（gum format → pager）→ q → メニューで Ctrl-C（終了。終了コードも見る）
Output docs/screens/kill-switches.gif
Output docs/screens/kill-switches.txt
Source docs/tapes/_settings.tape
Source docs/tapes/_env.tape

Hide
Type "clear"
Enter
Show

Type "versteck-remote-tui"
Enter
Sleep 1.5s
Down@300ms 4
Sleep 0.5s
Enter
Sleep 1.5s
Type "q"
Sleep 1s
Ctrl+C
Sleep 1s
Type "echo $?"
Enter
Sleep 0.5s
