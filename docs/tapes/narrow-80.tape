# 80 桁で崩れないか: メニュー → セッションを止める（枠付きの注意書き）→ 戻る → 状態の一覧（pager）→ q → 戻る
#                   → シェルへ降りる（枠付きの注意書き）→ いいえ → Esc（終了）
# 幅だけを共通の設定より狭くする（_settings.tape の後、_env.tape の前に置く）
Output docs/screens/narrow-80.gif
Output docs/screens/narrow-80.txt
Source docs/tapes/_settings.tape
Set Width 770
Source docs/tapes/_env.tape

Hide
Type "clear"
Enter
Show

Type "stty size"
Enter
Sleep 0.5s
Type "versteck-remote-tui"
Enter
Sleep 1.5s
Down@300ms 2
Sleep 0.5s
Enter
Sleep 1.5s
Down@300ms 3
Sleep 0.5s
Enter
Sleep 1s
Enter
Sleep 1.5s
Type "q"
Sleep 1s
Down
Sleep 0.5s
Enter
Sleep 1s
Down@300ms 5
Sleep 0.5s
Enter
Sleep 1.5s
Enter
Sleep 1s
Escape
Sleep 1s
