# 失敗のとき（終了コード 3）: 一覧にあるのに既に終わったセッション gone-1 を覗く・止める → 文言 → メニューへ戻る → Esc（終了）
# 偽のバックエンドは claude-1・muse-1 以外の peek・stop に 3 を返す。一覧に gone-1 を足した status を使う。
Output docs/screens/errors.gif
Output docs/screens/errors.txt
Source docs/tapes/_settings.tape
Source docs/tapes/_env.tape

Hide
Type `jq '.sessions += [{"name": "gone-1", "agent": "muse", "started_at": "2026-11-27T00:50:00Z"}]' tests/fixtures/status-ok.json >/tmp/vrs-status-gone.json && export FAKE_STATUS_JSON=/tmp/vrs-status-gone.json && clear`
Enter
Show

Type "versteck-remote-tui"
Enter
Sleep 1.5s
Down
Sleep 0.5s
Enter
Sleep 1.5s
Down@300ms 2
Sleep 0.5s
Enter
Sleep 2s
Down@300ms 2
Sleep 0.5s
Enter
Sleep 1.5s
Down@300ms 2
Sleep 0.5s
Enter
Sleep 1.5s
Left
Sleep 0.5s
Enter
Sleep 2s
Escape
Sleep 1s
