# versteck に期待するインターフェース（版 1）

versteck-remote-tui（以下 TUI）は versteck の中身を知りません。versteck 側が用意する 1 本のコマンド（以下「バックエンド」）だけを呼びます。この文書は、そのバックエンドが満たす形を決めます。

- 既定のパス: `/usr/local/sbin/versteck-ctl`
- 差し替え: 環境変数 `VERSTECK_TUI_BACKEND`（テストではこれで偽物に向けます）
- インターフェースの版: **1**

versteck 側の実装は、この文書と `tests/fixtures/fake-backend`（テスト用の偽物）を手本にできます。

## 共通の約束

### 終了コード

| コード | 意味 | TUI の表示 |
|---|---|---|
| 0 | 成功 | — |
| 2 | 使い方の誤り（知らないサブコマンド・引数の形の誤り） | 「使い方の誤り。TUI とバックエンドの版が合っていない可能性」 |
| 3 | 対象が無い（セッション名が無いなど） | 「対象が見つかりません」 |
| 4 | 取得できない（下回りの失敗） | 「情報を取得できませんでした」 |
| その他 | 予期しない失敗として扱う | 「予期しない失敗（終了コード N）」 |

TUI のテキストの呼び出し（`status` / `audit`）は、バックエンドの 3 と 4 をそのまま返し、それ以外の失敗を 1 にして返します。バックエンドの 2 は呼び出した人の誤りではないので、TUI 自身の「使い方の誤り」の 2 とは分けています。

### 出力

- 機械が読む出力（JSON・JSON Lines）は標準出力に、UTF-8 で出します。
- 失敗の説明は標準エラーに出します。TUI は標準エラーを画面に出しますが、中身では判定しません。
- 時刻は ISO 8601 の UTC で、`Z` を付けて出します（例 `2026-11-27T01:02:03Z`）。TUI は監査ログを時刻の文字列の順で並べるので、書式をそろえてください。
- TUI は表示する前に端末の制御文字を落とします。それでも、バックエンドの側でも制御列を出さないでください。

### セッション名

```
^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$
```

- 1〜64 文字。英数字・`.`・`_`・`-` だけを使います。
- 先頭は英数字にします。`-` で始まる名前は引数（`--all` など）と紛れるためです。
- TUI はこの形を通る名前だけをバックエンドに渡します。バックエンドの側でも同じ検査をしてください（sudoers の書き方によっては、ほかの形の引数も届きうるためです）。

## サブコマンド

### `interface-version`

```
$ versteck-ctl interface-version
{"interface":1}
```

- 常に終了コード 0 で、上の JSON を 1 行出します。
- TUI は起動時にこれを呼び、`interface` が 1 でなければ「インターフェースの版が合いません」と出して止まります。
- 認証の方式の判定（後述）にも使うので、副作用を持たせないでください。

### `status --json`

JSON のオブジェクトを 1 つ出します。

```json
{
  "host": "example-vm",
  "generated_at": "2026-11-27T01:02:03Z",
  "human_entrance": {"state": "active", "detail": "sshd running"},
  "tailscale": {"state": "connected", "detail": "logged in"},
  "disks": [
    {"mount": "/", "used_percent": 42},
    {"mount": "/var", "used_percent": 93}
  ],
  "sessions": [
    {"name": "claude-1", "agent": "claude-code", "started_at": "2026-11-27T00:00:00Z"}
  ]
}
```

| 項目 | 型 | 意味 |
|---|---|---|
| `host` | 文字列 | 画面に出すホスト名 |
| `generated_at` | 文字列（ISO 8601） | この JSON を作った時刻 |
| `human_entrance.state` | `active` / `inactive` / `failed` / `unknown` | 人の入口（admin が入る経路）の状態 |
| `human_entrance.detail` | 文字列 | 補足の 1 行（空でもよい） |
| `tailscale.state` | `connected` / `disconnected` / `unknown` | Tailscale の状態 |
| `tailscale.detail` | 文字列 | 補足の 1 行（空でもよい） |
| `disks[].mount` | 文字列 | マウント先 |
| `disks[].used_percent` | 数（0〜100） | 使用率 |
| `sessions[].name` | 文字列（セッション名の形） | エージェントのセッション名 |
| `sessions[].agent` | 文字列 | エージェントの種類 |
| `sessions[].started_at` | 文字列（ISO 8601） | 始まった時刻 |

- 一部を取れなかったときは、終了コード 4 で失敗させるより、その項目を `unknown` にするか省いて 0 で返すほうを勧めます。TUI は欠けた項目と決まった値以外の `state` を「不明」と出します。
- 動いているセッションが無いときは `"sessions": []` にします（省くと TUI は「不明」と出します）。

### `peek <session>`

- そのセッションの画面の文字を標準出力に出します。読み取り専用で、セッションには何も送りません。
- TUI はこれを pager で見せ、admin が「再読み込み」を選ぶたびに呼び直します。TUI は tmux attach をしません。
- セッションが無ければ終了コード 3 で終わります。

### `stop <session>` / `stop --all`

- エージェントのセッションだけを止めます。**人の入口は止めません。**
- `stop --all` は、動いているエージェントのセッションをすべて止めます。
- 止めた結果の短い説明を標準出力に出してかまいません（TUI はそのまま見せます）。
- セッションが無ければ終了コード 3 で終わります。

### `audit --json [--limit N]`

JSON Lines を出します。1 行が 1 件です。

```
{"time":"2026-11-27T00:30:00Z","agent":"muse","command":"rm -rf /tmp/x","result":"denied","detail":"not allowed"}
```

| 項目 | 型 | 意味 |
|---|---|---|
| `time` | 文字列（ISO 8601、UTC、`Z` 付き） | 起きた時刻 |
| `agent` | 文字列 | エージェント名 |
| `command` | 文字列 | エージェントが実行しようとしたコマンド |
| `result` | `ok` / `denied` / `error` | 結果 |
| `detail` | 文字列 | 補足（空でもよい） |

- `--limit N` は新しいほうから N 件までを返します。並び順は問いません（TUI が新しい順に並べ直します）。
- TUI のメニューは `--limit 200`、テキストの `audit` は `--limit N`（既定 20、1〜9999）で呼びます。
- 絞り込み（失敗だけ・エージェント名）は TUI が jq で行います。「失敗」は `result` が `ok` でないもの（`denied`・`error`・欠け）です。
- JSON として読めない行を TUI は飛ばします。

### `kill-switches`

- 止め方の手順を Markdown で標準出力に出します。
- 正本の文書は versteck 側にあります。TUI は読んで `gum format` で見せるだけで、手順の中身を持ちません。

## 認証と sudoers

TUI は起動時に `sudo -k -n -- <バックエンド> interface-version` を試し、結果で方式を決めます。どちらの方式でも、以後のバックエンドの呼び出しはすべて `sudo -n -- <バックエンド> <引数...>` の形です。

判定に `-k` を付けるのは、sudo の期限（タイムスタンプ）をその 1 回だけ無視するためです。同じ端末で先に sudo を使っていると、`-k` が無ければ期限のおかげで `sudo -n` が通り、A と取り違えます。そうなると背景の更新が始まらず、期限が切れた後の呼び出しがすべて失敗します。`-k` をコマンドと一緒に付けても、残っている期限は消えません。

- この `-k` の動きは、sudo（1.9 系）の説明書きに沿ったものです。sudo-rs で `-k` をコマンドと一緒に付けたときの動きは確かめていません。sudo-rs を使う環境では、期限を残した端末から起動して、A と B を正しく判定するかを実機で確かめてください。

| 方式 | 条件 | 動き |
|---|---|---|
| A | sudoers でバックエンドの決まった引数の形だけが NOPASSWD | 鍵のログインだけで動きます。パスワードは聞きません |
| B | A が通らない | `sudo -v` で 1 回だけパスワードを聞きます。背景で `sudo -n -v` を 60 秒ごとに呼んで期限を延ばし、TUI の終了で止めます |

`VERSTECK_TUI_SUDO=never` を設定すると sudo を付けずに直接呼びます（テストと、root で動かすとき用）。

### A の方式で versteck 側が書く sudoers の例

`versteck-admin` が、バックエンドの決まった引数の形だけをパスワードなしで実行できるようにします。ファイルは versteck 側が置き、置く前に `visudo -cf <ファイル>` で検査してください。

```sudoers
# /etc/sudoers.d/versteck-remote-tui（例）
Cmnd_Alias VERSTECK_TUI_FIXED = \
    /usr/local/sbin/versteck-ctl interface-version, \
    /usr/local/sbin/versteck-ctl status --json, \
    /usr/local/sbin/versteck-ctl kill-switches, \
    /usr/local/sbin/versteck-ctl audit --json --limit 200, \
    /usr/local/sbin/versteck-ctl stop --all

# 引数に変わる部分があるもの。sudo 1.9.10 以降の正規表現の書き方（^ で始まり $ で終わる）
Cmnd_Alias VERSTECK_TUI_ARGS = \
    /usr/local/sbin/versteck-ctl ^peek [A-Za-z0-9][A-Za-z0-9._-]{0,63}$, \
    /usr/local/sbin/versteck-ctl ^stop [A-Za-z0-9][A-Za-z0-9._-]{0,63}$, \
    /usr/local/sbin/versteck-ctl ^audit --json --limit [1-9][0-9]{0,3}$

versteck-admin ALL=(root) NOPASSWD: VERSTECK_TUI_FIXED, VERSTECK_TUI_ARGS
```

**ワイルドカードの危うさ。** `versteck-ctl stop *` のように書くと、`*` は空白を含むどんな文字列にも当たります。`stop --all`、`stop a b c`、`stop --force x` のような、TUI が渡さない形もパスワードなしで通ってしまいます。`peek *` も同じです。引数が変わる部分は、上のように正規表現で形を固定してください。

- 正規表現の書き方は sudo 1.9.10 以降のものです。使っている sudo の実装と版（Ubuntu では sudo-rs が既定になっている版があります）がこの書き方を受け付けるかを、`visudo -cf` と実機で確かめてください。受け付けない場合は、変わる部分を持つ行を NOPASSWD から外し、その操作だけ B の方式（パスワード）にするのが安全です。
- 正規表現で形を固定しても、バックエンドの側でもセッション名を検査してください（二重の守り）。

### B の方式の注意

- `sudo -v` の期限（`timestamp_timeout`）の間は、同じ端末からほかの sudo もパスワードなしで通ります。TUI が背景で期限を延ばしている間も同じです。「シェルへ降りる」を選ぶと TUI は更新を止めますが、すでに延びた期限はそのまま残ります。
- 期限の管理が端末ごと（`timestamp_type=tty`）の場合、背景の更新は TUI と同じ端末で動くので延長が効く想定です（実機では未確認）。

## 版の決まり

- この文書の版（インターフェースの版）は、バックエンドの `interface-version` が返す数と同じです。
- 項目の追加（JSON に新しいキーを足す、新しいサブコマンドを足す）は版を上げません。TUI は知らないキーを無視します。
- 既存の項目の意味・型・終了コードを変える、サブコマンドや引数を消す、のように古い TUI が壊れる変更は版を上げます。
- TUI は自分が期待する版と一致しないバックエンドでは動きません。インターフェースの版を上げる変更をしたら、TUI のメジャーの版も上げます（README の「版の決まり」）。
