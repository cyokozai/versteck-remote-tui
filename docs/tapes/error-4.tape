# 失敗のとき（終了コード 4）: バックエンドの下回りが失敗 → 状態の一覧 → 文言 → メニューへ戻る → Esc（終了）
Output docs/screens/error-4.gif
Output docs/screens/error-4.txt
Source docs/tapes/_settings.tape
Source docs/tapes/_env.tape

Hide
Type "export FAKE_BACKEND_FAIL=4 && clear"
Enter
Show

Type "versteck-remote-tui"
Enter
Sleep 1.5s
Enter
Sleep 2s
Escape
Sleep 1s
