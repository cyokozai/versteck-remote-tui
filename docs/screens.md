# 画面と画面遷移の設計

この文書は versteck-remote-tui の画面ごとの見た目と、画面どうしの行き来を決める正本です。

画面の文字は手で整えた図ではありません。`make screens` で VHS の端末に TUI を流し、その端末に出た文字を写しています。バックエンドは偽物（`tests/fixtures/fake-backend` と `status-ok.json`・`audit.jsonl`）で、`VERSTECK_TUI_SUDO=never` で動かしています。そのため上部の表示は `auth: no sudo`、ホスト名は `example-vm`、セッションは `claude-1` と `muse-1` です。

- 端末の大きさ: 100 桁 × 30 行（80 桁の確認は [80 桁で見たとき](#80-桁で見たとき)）
- gum: 0.17.0（上流のリリースの .deb。`Dockerfile.vhs`）
- 録画: 各画面の下に、GIF・テキスト出力・操作スクリプトへのリンクを置きます
- 録画とテキスト出力の作り方は [録画の作り方](#録画の作り方) にあります

## 目次

- [遷移の地図](#遷移の地図)
- [遷移の表](#遷移の表)
- [画面](#画面)
  - [メニュー](#メニュー)
  - [状態の一覧](#状態の一覧)
  - [セッションを覗く](#セッションを覗く)
  - [セッションを止める](#セッションを止める)
  - [監査ログ](#監査ログ)
  - [止め方の手順](#止め方の手順)
  - [シェルへ降りる](#シェルへ降りる)
  - [メニューを出せないとき](#メニューを出せないとき)
  - [失敗のとき](#失敗のとき)
  - [80 桁で見たとき](#80-桁で見たとき)
- [gum の部品のキー](#gum-の部品のキー)
- [録画の作り方](#録画の作り方)

## 遷移の地図

`[ ]` は画面、`( )` は画面を持たない処理です。矢印の脇に操作を書きます。Esc はどの選択の画面でも `Back` と同じ行き先です。

                  versteck-remote-tui (from a terminal, no arguments)
                                      │
                 (check gum and jq, auth A / B / none, backend version)
                         │ passed                    │ failed
                         ▼                           ▼
   ┌──────────────────────────────────┐   [cannot show menu] ──▶ (login shell)
   │              [Menu]              │
   │ Quit / Esc / Ctrl-C ──▶ (leave the TUI. Exit code 0 / 0 / 130)
   └──┬──────┬──────┬──────┬──────┬───┘
      │      │      │      │      │      └── Drop to shell ──▶ [notice + confirm]
      │      │      │      │      │                              │ Yes ──▶ (login shell)
      │      │      │      │      │                              │ No・Esc ──▶ [Menu]
      │      │      │      │      └── Kill switches ──▶ [pager] ── q・Esc ──▶ [Menu]
      │      │      │      └── Audit log ──▶ [choose filter] ◀────────────────────┐
      │      │      │                         │ All・Failures only ──▶ [pager] ── q ─┤
      │      │      │                         │ Filter by agent ──▶ [filter]       │
      │      │      │                         │     Enter ──▶ [pager] ── q ────────┤
      │      │      │                         │     Esc ──────────────────────────┘
      │      │      │                         └ Back・Esc ──▶ [Menu]
      │      │      └── Stop session ──▶ [notice + choose]
      │      │                                   │ 0 sessions ──▶ "No agent sessions are running." ──▶ [Menu]
      │      │                                   │ name・Stop all ──▶ [confirm]
      │      │                                   │     Yes ──▶ (stop) ──▶ "Stopped." ──▶ [Menu]
      │      │                                   │     No・Esc ──▶ "Nothing was stopped." ──▶ [Menu]
      │      │                                   └ Back・Esc ──▶ [Menu]
      │      └── Peek session ──▶ [choose] ── name ──▶ [pager] ── q ──▶ [Reload / Back]
      │                                │                     ▲              │ Reload
      │                                │                     └──────────────┘
      │                                └ Back・Esc / 0 sessions ──▶ [Menu]   Back・Esc ──▶ [Menu]
      └── Status ──▶ [pager] ── q ──▶ [Reload / Back] ── Reload ──▶ [pager]
                                                         └── Back・Esc ──▶ [Menu]

   Backend failure (exit code 2, 3, 4, other): print a red message and return to [Menu]

## 遷移の表

「キー」は gum の部品の既定のキーです（[gum の部品のキー](#gum-の部品のキー)）。「録画」はその遷移を流した操作スクリプトです。録画が「なし」の行は、コード（`lib/versteck-remote-tui/*.sh`）から読んだ行き先で、端末では確かめていません。

| いる画面 | 操作 | 行き先 | 録画 |
|---|---|---|---|
| シェル | `versteck-remote-tui` | メニュー | menu-status |
| シェル | `versteck-remote-tui`（認証 B） | `Passwordless sudo is not available, so the sudo password is asked once.`→ メニュー（上部が `auth: B`） | auth-b |
| シェル | `versteck-remote-tui`（バックエンドが無い・版が合わない・sudo に失敗・gum か jq が無い） | 文言 → ログインシェル（確認なし） | no-menu（バックエンドが無い場合だけ） |
| メニュー | ↑↓ で `Status`・Enter | 状態の一覧（pager） | menu-status |
| メニュー | `Peek session`・Enter | 覗くセッションの選択 | peek |
| メニュー | `Stop session`・Enter | 注意書き + 止めるセッションの選択 | stop-one |
| メニュー | `Audit log`・Enter | 絞り方の選択 | audit |
| メニュー | `Kill switches`・Enter | 止め方の手順（pager） | kill-switches |
| メニュー | `Drop to shell`・Enter | 注意書き + 確認 | shell |
| メニュー | `Quit`・Enter | TUI を終える（終了コード 0） | menu-status |
| メニュー | Esc | TUI を終える（終了コード 0 はコードから読んだもの）。gum が出す `nothing selected` の行は TUI が消す | peek |
| メニュー | Ctrl-C | TUI を終える（終了コード 130） | kill-switches |
| 状態の一覧（pager） | q・Esc | `Reload` / `Back` の選択 | menu-status（q） |
| `Reload` / `Back`（状態） | `Reload`・Enter | 状態の一覧（取り直す） | menu-status |
| `Reload` / `Back`（状態） | `Back`・Enter・Esc | メニュー | menu-status（戻る） |
| 覗くセッションの選択 | 名前・Enter | セッションの画面（pager） | peek |
| 覗くセッションの選択 | `Back`・Enter・Esc | メニュー | なし |
| 覗くセッションの選択 | （セッションが 0 件） | `No agent sessions are running.`→ メニュー | なし |
| セッションの画面（pager） | q・Esc | `Reload` / `Back` の選択 | peek（q） |
| `Reload` / `Back`（覗く） | `Reload` | セッションの画面（取り直す） | peek |
| `Reload` / `Back`（覗く） | `Back`・Esc | メニュー | peek（戻る） |
| 止めるセッションの選択 | 名前・Enter | 確認（`Stop session "名前"?`） | stop-one |
| 止めるセッションの選択 | `Stop all`・Enter | 確認（`Stop all N agent session(s)?`） | stop-all |
| 止めるセッションの選択 | `Back`・Enter・Esc | メニュー | narrow-80（戻る） |
| 止めるセッションの選択 | （セッションが 0 件） | `No agent sessions are running.`→ メニュー（選択は出ない） | stop-empty |
| 止める確認 | ← で `Yes`・Enter（または y） | 止める →`Stopped.` とバックエンドの出力 → メニュー | stop-one・stop-all |
| 止める確認 | Enter（既定は `No`）・n・Esc | `Nothing was stopped.`→ メニュー | stop-one（Enter） |
| 絞り方の選択 | `All`・`Failures only` | 監査ログ（pager） | audit |
| 絞り方の選択 | `Filter by agent` | エージェント名の filter | audit |
| 絞り方の選択 | `Back`・Esc | メニュー | audit（戻る） |
| エージェント名の filter | 文字を打って絞る・Enter | 監査ログ（pager。見出しに名前） | audit |
| エージェント名の filter | Esc | 絞り方の選択 | なし |
| 監査ログ（pager） | q・Esc | 絞り方の選択 | audit（q） |
| 止め方の手順（pager） | q・Esc | メニュー | kill-switches（q） |
| シェルへ降りる確認 | ← で `Yes`・Enter（または y） | ログインシェル（`VERSTECK_REMOTE_TUI_SKIP=1`） | shell |
| シェルへ降りる確認 | Enter（既定は `No`）・n・Esc | `Did not drop to a shell.` → メニュー | shell |
| 各画面 | バックエンドが終了コード 3 | `Target not found (exit code 3). …`→ メニュー | errors（覗く・止める） |
| 各画面 | バックエンドが終了コード 4 | `Could not get the information (exit code 4). …`→ メニュー | error-4（状態の一覧） |
| 各画面 | バックエンドが終了コード 2・その他 | 終了コードに応じた文言 → メニュー | なし |
| 選択・確認・filter の画面 | Ctrl-C | 選択・確認と同じく `Back` / `No` の扱い（gum が 0 以外で終わるため） | なし（メニューの Ctrl-C だけ録画） |

## 画面

ここに置く枠はテキスト出力の 1 コマをそのまま写したものです。1 行目の `> versteck-remote-tui` は、VHS のシェルで TUI を起動した行です。pager は端末の下まで `~` の行で埋まります。状態の一覧の枠だけはそのまま載せ、ほかの pager では `~` の行を省きました。

### メニュー

起動すると、上部に版・認証の方式・バックエンドのパスを出し、その下に 7 つの項目を並べます。認証の表示は 3 通りです。

- `auth: A (SSH key only, sudoers)`
- `auth: B (sudo password, refreshed every 60 s)`（60 は `VERSTECK_TUI_SUDO_REFRESH`）
- `auth: no sudo`（`VERSTECK_TUI_SUDO=never`）

```text
> versteck-remote-tui
versteck-remote-tui 0.0.0-dev | auth: no sudo
Backend: /src/tests/fixtures/fake-backend
> Status
  Peek session
  Stop session
  Audit log
  Kill switches
  Drop to shell
  Quit


←↓↑→ navigate • enter submit
```

認証 B のときは、メニューの前に 1 行出ます。偽の sudo はパスワードを聞かずに通すので、パスワードの入力欄は録画に出ません。認証 A の画面は偽の sudo の `nopasswd` の形で録れますが、この PR では録っていません。

```text
> versteck-remote-tui
Passwordless sudo is not available, so the sudo password is asked once.
versteck-remote-tui 0.0.0-dev | auth: B (sudo password, refreshed every 60 s)
Backend: /src/tests/fixtures/fake-backend
> Status
  Peek session
  Stop session
  Audit log
  Kill switches
  Drop to shell
  Quit


←↓↑→ navigate • enter submit
```

録画: [menu-status.gif](screens/menu-status.gif)・[テキスト](screens/menu-status.txt)・[操作スクリプト](tapes/menu-status.tape)／認証 B: [auth-b.gif](screens/auth-b.gif)・[テキスト](screens/auth-b.txt)・[操作スクリプト](tapes/auth-b.tape)

### 状態の一覧

pager で見せます。q で閉じると `Reload` / `Back` を選びます。再読み込みを選ぶと、バックエンドから取り直して pager を開き直します。

```text
╭──────────────────────────────────────────────────────────────────────────────────────────────────╮
│    1 │ Status (fetched 21:15:39)                                                                 │
│    2 │                                                                                           │
│    3 │ Host: example-vm                                                                          │
│    4 │ Generated at: 2026-11-27T01:02:03Z                                                        │
│    5 │ Human entrance: active sshd running                                                       │
│    6 │ Tailscale: connected logged in                                                            │
│    7 │ Disks:                                                                                    │
│    8 │   / 42%                                                                                   │
│    9 │   /var 93% nearly full                                                                    │
│   10 │ Sessions: 2                                                                               │
│   11 │   claude-1 claude-code 2026-11-27T00:00:00Z                                               │
│   12 │   muse-1 muse 2026-11-26T23:00:00Z                                                        │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
│    ~ │                                                                                           │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
↓↑ navigate • esc quit • / search
```

```text
> versteck-remote-tui
Status
> Reload
  Back


←↓↑→ navigate • enter submit
```

録画: [menu-status.gif](screens/menu-status.gif)・[テキスト](screens/menu-status.txt)・[操作スクリプト](tapes/menu-status.tape)

### セッションを覗く

セッションを選び、その画面の文字を pager で見せます。読み取り専用で、tmux attach はしません。q で閉じると `Reload` / `Back` を選びます。

```text
> versteck-remote-tui
Choose a session to peek at (read-only)
> claude-1
  muse-1
  Back


←↓↑→ navigate • enter submit
```

```text
╭──────────────────────────────────────────────────────────────────────────────────────────────────╮
│    1 │ Session claude-1 screen (read-only, fetched 21:16:40)                                     │
│    2 │                                                                                           │
│    3 │ screen of claude-1                                                                        │
│    4 │ $ echo hi                                                                                 │
│    5 │ hi                                                                                        │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
↓↑ navigate • esc quit • / search
```

```text
> versteck-remote-tui
Session claude-1
> Reload
  Back


←↓↑→ navigate • enter submit
```

録画: [peek.gif](screens/peek.gif)・[テキスト](screens/peek.txt)・[操作スクリプト](tapes/peek.tape)

### セッションを止める

この画面に入るたびに、枠付きの注意書きを出します。確認の画面にも同じ注意書きを出します。確認の既定は `No` です。

#### 選ぶ

```text
> versteck-remote-tui
┌────────────────────────────────────────────────────────────────────┐
│ Only agent sessions are stopped. The human entrance keeps running. │
│ The only sure way to stop everything is to stop the VM             │
│ (see Kill switches).                                               │
└────────────────────────────────────────────────────────────────────┘
Choose a session to stop
> claude-1
  muse-1
  Stop all
  Back


←↓↑→ navigate • enter submit
```

#### 確認（1 件）

```text
> versteck-remote-tui
┌────────────────────────────────────────────────────────────────────┐
│ Only agent sessions are stopped. The human entrance keeps running. │
│ The only sure way to stop everything is to stop the VM             │
│ (see Kill switches).                                               │
└────────────────────────────────────────────────────────────────────┘
 Only agent sessions are stopped. The human entrance keeps running.
 The only sure way to stop everything is to stop the VM
 (see Kill switches).

 Stop session "claude-1"?

    Yes        No

←→ toggle • enter submit • y Yes • n No
```

確認（すべて）は、最後の行が `Stop all 2 agent session(s)?` になります。

#### 結果

いいえ、はいの順に流したものです。`Stopped.` の次の行はバックエンドの出力です。

```text
> versteck-remote-tui
┌────────────────────────────────────────────────────────────────────┐
│ Only agent sessions are stopped. The human entrance keeps running. │
│ The only sure way to stop everything is to stop the VM             │
│ (see Kill switches).                                               │
└────────────────────────────────────────────────────────────────────┘
Nothing was stopped.
┌────────────────────────────────────────────────────────────────────┐
│ Only agent sessions are stopped. The human entrance keeps running. │
│ The only sure way to stop everything is to stop the VM             │
│ (see Kill switches).                                               │
└────────────────────────────────────────────────────────────────────┘
Stopped.
stopped claude-1
versteck-remote-tui 0.0.0-dev | auth: no sudo
Backend: /src/tests/fixtures/fake-backend
> Status
  Peek session
  Stop session
  Audit log
  Kill switches
  Drop to shell
  Quit


←↓↑→ navigate • enter submit
```

#### 0 件

セッションが無いときは、選択を出さずにメニューへ戻ります。

```text
> versteck-remote-tui
┌────────────────────────────────────────────────────────────────────┐
│ Only agent sessions are stopped. The human entrance keeps running. │
│ The only sure way to stop everything is to stop the VM             │
│ (see Kill switches).                                               │
└────────────────────────────────────────────────────────────────────┘
No agent sessions are running.
versteck-remote-tui 0.0.0-dev | auth: no sudo
Backend: /src/tests/fixtures/fake-backend
> Status
  Peek session
  Stop session
  Audit log
  Kill switches
  Drop to shell
  Quit


←↓↑→ navigate • enter submit
```

#### 録画

- 1 件（いいえ・はい）: [stop-one.gif](screens/stop-one.gif)・[テキスト](screens/stop-one.txt)・[操作スクリプト](tapes/stop-one.tape)
- すべて止める: [stop-all.gif](screens/stop-all.gif)・[テキスト](screens/stop-all.txt)・[操作スクリプト](tapes/stop-all.tape)
- 0 件: [stop-empty.gif](screens/stop-empty.gif)・[テキスト](screens/stop-empty.txt)・[操作スクリプト](tapes/stop-empty.tape)

### 監査ログ

絞り方を選び、pager で見せます。pager を閉じると絞り方の選択に戻ります。メニューへ戻るのは `Back` か Esc です。

#### 絞り方の選択

```text
> versteck-remote-tui
Audit log (latest 200 entries, newest first)
> All
  Failures only
  Filter by agent
  Back


←↓↑→ navigate • enter submit
```

#### エージェント名の filter

`mu` と打ったところです。filter は端末の全体を使い、案内の行は最下行に出ます。間の空行（26 行）は省きました。

```text
> mu
• muse

↓↑ navigate • esc blur search • enter submit
```

#### 一覧（すべて）

```text
╭──────────────────────────────────────────────────────────────────────────────────────────────────╮
│    1 │ Audit log: All                                                                            │
│    2 │ Time  Result  Agent  Command  Detail                                                      │
│    3 │                                                                                           │
│    4 │ 2026-11-27T00:40:00Z  ok  muse  ls                                                        │
│    5 │ 2026-11-27T00:30:00Z  denied  muse  rm -rf /tmp/x  not allowed                            │
│    6 │ 2026-11-27T00:20:00Z  error  claude-code  make test  exit 2                               │
│    7 │ 2026-11-27T00:10:00Z  ok  claude-code  git status                                         │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
↓↑ navigate • esc quit • / search
```

#### 一覧（失敗だけ）

```text
╭──────────────────────────────────────────────────────────────────────────────────────────────────╮
│    1 │ Audit log: Failures only                                                                  │
│    2 │ Time  Result  Agent  Command  Detail                                                      │
│    3 │                                                                                           │
│    4 │ 2026-11-27T00:30:00Z  denied  muse  rm -rf /tmp/x  not allowed                            │
│    5 │ 2026-11-27T00:20:00Z  error  claude-code  make test  exit 2                               │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
↓↑ navigate • esc quit • / search
```

#### 一覧（エージェント名で絞る）

```text
╭──────────────────────────────────────────────────────────────────────────────────────────────────╮
│    1 │ Audit log: Filter by agent (muse)                                                         │
│    2 │ Time  Result  Agent  Command  Detail                                                      │
│    3 │                                                                                           │
│    4 │ 2026-11-27T00:40:00Z  ok  muse  ls                                                        │
│    5 │ 2026-11-27T00:30:00Z  denied  muse  rm -rf /tmp/x  not allowed                            │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
↓↑ navigate • esc quit • / search
```

録画: [audit.gif](screens/audit.gif)・[テキスト](screens/audit.txt)・[操作スクリプト](tapes/audit.tape)

### 止め方の手順

バックエンドの `kill-switches` が出す Markdown を `gum format` で整え、pager で見せます。下は偽のバックエンドの短い手順です。閉じるとメニューへ戻ります。

```text
╭──────────────────────────────────────────────────────────────────────────────────────────────────╮
│    1 │   止め方                                                                                  │
│    2 │                                                                                           │
│    3 │   1. VM を止める                                                                          │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
↓↑ navigate • esc quit • / search
```

録画（メニューで Ctrl-C を押して終える所まで）: [kill-switches.gif](screens/kill-switches.gif)・[テキスト](screens/kill-switches.txt)・[操作スクリプト](tapes/kill-switches.tape)

### シェルへ降りる

枠付きの注意書きを出し、確認します。既定は `No` で、`No` ならメニューへ戻ります。`Yes` なら `VERSTECK_REMOTE_TUI_SKIP=1` を立てて `exec bash -l` します。

注意書きは手で 4 行に分けてあり、枠は 72 桁です。100 桁にも 80 桁にも収まります。

```text
> versteck-remote-tui
┌──────────────────────────────────────────────────────────────────────┐
│ Dropping to a shell. Commands from here on do not go through         │
│ the TUI, so they are outside the TUI record. The sudo refresh stops. │
│ VERSTECK_REMOTE_TUI_SKIP=1 is set so that the menu does not          │
│ start again in the login shell.                                      │
└──────────────────────────────────────────────────────────────────────┘
 Drop to a shell?

    Yes        No

←→ toggle • enter submit • y Yes • n No
```

`Yes` を選んだ後の画面です。`root@example-vm` は録画のコンテナのプロンプトです。

```text
root@example-vm:/src# echo VERSTECK_REMOTE_TUI_SKIP=$VERSTECK_REMOTE_TUI_SKIP
VERSTECK_REMOTE_TUI_SKIP=1
root@example-vm:/src#
```

録画: [shell.gif](screens/shell.gif)・[テキスト](screens/shell.txt)・[操作スクリプト](tapes/shell.tape)

### メニューを出せないとき

バックエンドが無い・版が合わない・sudo の確認に失敗した・gum か jq が無い、のどれかなら、理由を出して確認なしでシェルへ降ります。録画はバックエンドが無い場合です。

```text
> versteck-remote-tui
Backend not found: /usr/local/sbin/versteck-ctl (it is installed on the versteck side; set VERSTECK_
TUI_BACKEND to change the location)
The menu cannot be shown, so dropping to a shell (outside the TUI record).
root@example-vm:/src# echo VERSTECK_REMOTE_TUI_SKIP=$VERSTECK_REMOTE_TUI_SKIP
VERSTECK_REMOTE_TUI_SKIP=1
root@example-vm:/src#
```

録画: [no-menu.gif](screens/no-menu.gif)・[テキスト](screens/no-menu.txt)・[操作スクリプト](tapes/no-menu.tape)

### 失敗のとき

バックエンドが 0 以外で終わると、赤い文言を出してメニューへ戻ります。バックエンドが標準エラーに出した行も、その上に残ります。

#### 終了コード 3

一覧にはあるが、もう終わったセッション `gone-1` を覗いたときです。

```text
Choose a session to peek at (read-only)
  claude-1
  muse-1
> gone-1
  Back
no such session: gone-1
Target not found (exit code 3). The session may have already ended.
versteck-remote-tui 0.0.0-dev | auth: no sudo
Backend: /src/tests/fixtures/fake-backend
> Status
  Peek session
  Stop session
  Audit log
  Kill switches
  Drop to shell
  Quit


←↓↑→ navigate • enter submit
```

この枠は選択の画面のコマと、その次のコマを 1 つにつないだものです（選択の画面は閉じると消えるので、テキスト出力の 1 コマには両方は残りません）。止める画面で `gone-1` を選んで `Yes` にしたときも、同じ文言でメニューへ戻ります。

#### 終了コード 4

偽のバックエンドを `FAKE_BACKEND_FAIL=4` で動かし、状態の一覧を開いたときです。

```text
> versteck-remote-tui
fake backend: failing with 4
Could not get the information (exit code 4). The backend failed internally.
versteck-remote-tui 0.0.0-dev | auth: no sudo
Backend: /src/tests/fixtures/fake-backend
> Status
  Peek session
  Stop session
  Audit log
  Kill switches
  Drop to shell
  Quit


←↓↑→ navigate • enter submit
```

文言の一覧は `vrt_backend_error_message`（`lib/versteck-remote-tui/common.sh`）と [docs/interface.md](interface.md) の「終了コード」にあります。

録画: 終了コード 3 は [errors.gif](screens/errors.gif)・[テキスト](screens/errors.txt)・[操作スクリプト](tapes/errors.tape)、終了コード 4 は [error-4.gif](screens/error-4.gif)・[テキスト](screens/error-4.txt)・[操作スクリプト](tapes/error-4.tape)

### 80 桁で見たとき

メニュー・止める画面の注意書き・pager は 80 桁に収まります。止める画面の枠は 70 桁、シェルへ降りる画面の枠は 72 桁で、どちらも収まります。

```text
> versteck-remote-tui
┌────────────────────────────────────────────────────────────────────┐
│ Only agent sessions are stopped. The human entrance keeps running. │
│ The only sure way to stop everything is to stop the VM             │
│ (see Kill switches).                                               │
└────────────────────────────────────────────────────────────────────┘
Choose a session to stop
> claude-1
  muse-1
  Stop all
  Back


←↓↑→ navigate • enter submit
```

録画: [narrow-80.gif](screens/narrow-80.gif)・[テキスト](screens/narrow-80.txt)・[操作スクリプト](tapes/narrow-80.tape)

## gum の部品のキー

gum 0.17.0 の既定のキーです。各部品が画面の下に出す 1 行の案内と、録画で確かめたことを並べます。

| 部品 | 使う画面 | 画面の案内 | 確かめたこと |
|---|---|---|---|
| `gum choose` | メニュー・各選択 | `←↓↑→ navigate • enter submit` | ↑↓ と Enter で選べる。Esc で 0 以外で終わり、gum が `nothing selected` を端末に出す（TUI がその行を消す。録画で確かめた）。Ctrl-C でも 0 以外で終わる |
| `gum confirm` | 止める・シェルへ降りる | `←→ toggle • enter submit • y Yes • n No` | ← で `Yes` に移り、Enter で決まる。既定の `No` のまま Enter で `No`。y・n・Esc は録画していない |
| `gum filter` | 監査ログのエージェント名 | `↓↑ navigate • esc blur search • enter submit` | 打った文字で候補が絞られ、Enter で決まる。Esc は録画していない |
| `gum pager` | 状態の一覧・覗く・監査ログ・止め方の手順 | `↓↑ navigate • esc quit • / search` | q で閉じる。Esc・`/` は録画していない |

TUI の側では、選択・確認・filter が 0 以外で終わったとき（Esc・Ctrl-C）を `Back` / `No` と同じに扱います。メニューの Esc は `Quit` と同じで、TUI は終了コード 0 で終わります。メニューの Ctrl-C だけは、TUI が終了コード 130 で終わります（kill-switches の録画で `echo $?` が 130）。

## 実装との食い違い

録画で見つけた、設計として見直したほうがよさそうな所です。録画を撮り直した時点でコードに残っていたものだけを書きます。

前の版にあった次の 4 点は、いまのコードと録画では起きていません。

1. シェルへ降りる画面の注意書きの枠が折り返して崩れる点は、注意書きを 4 行に分けて直っています（shell・narrow-80 の録画）。
2. メニューの Ctrl-C の終了コードは 130 です（kill-switches の録画）。
3. Esc で抜けたとき、gum の `nothing selected` は端末に残りません（peek の録画。`Esc` の直後、起動した行のすぐ下にプロンプトが出る）。
4. シェルへ降りる確認で `No` を選ぶと `Did not drop to a shell.` が出ます（shell の録画）。

別の食い違いが 1 つあります。

- 偽のバックエンドの `kill-switches` の出力は日本語の手順書です。これはバックエンド側の文言なので、TUI の英語化では変えていません。止め方の手順の録画にだけ日本語が出ます。

## 録画の作り方

```sh
make screens                                   # 全部の操作スクリプトを流し直す
make screens TAPES=docs/tapes/stop-one.tape    # 1 本だけ
```

- `Dockerfile.vhs` が、VHS の公式 image（`ghcr.io/charmbracelet/vhs:v0.10.0`、Debian 12）に gum 0.17.0・jq・日本語の書体（Noto Sans Mono CJK JP）を足した image を作ります。gum は上流のリリースの .deb を、同じリリースの `checksums.txt` で照合してから入れます。手元には何も入れません。
- `docs/tapes/record.sh` が、コンテナの中で操作スクリプトを 1 本ずつ VHS に流し、GIF を小さく作り直します。VHS の GIF は 25 コマ／秒で全面を描き直すので、1 本 5MB ほどになります（`Set Framerate` は GIF に効きませんでした）。同じ絵が続くコマを落とし、32 色で書き直すと 0.1〜1MB になります。表示の時間は変わりません。
- 共通の設定は `docs/tapes/_settings.tape`（端末の大きさ・書体）と `docs/tapes/_env.tape`（偽のバックエンドを使う環境変数）です。`_` で始まる操作スクリプトは録画しません。`_size.tape` は端末が 100 桁 × 30 行になっているかを確かめる補助です。
- コンテナのホスト名は `example-vm` にしてあります（シェルへ降りた後のプロンプトに出るため）。

### テキスト出力

- VHS のテキスト出力は `.txt` と `.ascii` のどちらでも同じ形でした。この文書では `.txt` を使います。1 本の操作スクリプトに `.txt` と `.ascii` を両方書くと、片方しか出ませんでした。
- テキスト出力は時間ではなく、操作スクリプトの命令（`Type`・`Enter`・`Sleep`・キー）ごとに 1 コマを書きます。コマの区切りは `─` を 80 個並べた行です（端末の幅によらず 80 個）。
- 各コマはその時点の端末の文字です。pager のような全画面の部品も、開いている間のコマに出ます。閉じた後のコマには残りません。
- `Hide` の間に打ったコマンドもテキスト出力には出ます（errors・stop-empty の 2 コマ目など）。GIF には出ません。
- 時刻（「取得 02:04:28」など）は流すたびに変わります。
