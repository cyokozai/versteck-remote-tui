# versteck-remote-tui

versteck の VM に admin（人間の管理者）が SSH で入ったときに使う TUI です。エージェントのセッションの様子を見て、必要なら止め、監査ログを読み、止め方の手順を確かめます。

versteck は VM に AI エージェント（Claude Code・Muse など）を住まわせる仕組みです。この TUI は versteck の中身を知りません。versteck 側が用意するコマンド（バックエンド）だけを呼びます。バックエンドに求める形は [docs/interface.md](docs/interface.md)（インターフェースの版 1）に書いてあります。

## 画面

起動すると、上部に版・認証の方式・バックエンドのパスを出し、次の 6 つのメニューを並べます。

| 画面 | すること |
|---|---|
| 状態の一覧 | 人の入口・エージェントのセッション・Tailscale・ディスクを見せます。再読み込みできます |
| セッションを覗く | 選んだセッションの画面の文字を pager で見せます。読み取り専用で、tmux attach はしません |
| セッションを止める | 選んで確認してから止めます。「すべて止める」も確認付きです。この画面には「人の入口は止まりません」「確実に止まるのは VM を止めることです」を毎回出します |
| 監査ログ | 新しい順に見せます。「失敗だけ」と「エージェント名で絞る」を選べます。絞り込みは TUI が jq で行います |
| 止め方の手順 | バックエンドの `kill-switches` が出す Markdown を `gum format` で見せます |
| シェルへ降りる | `exec bash -l` でログインシェルに移ります。TUI が壊れても入れる逃げ道です。降りた先の操作は TUI の記録の外です |

Ansible の再実行と PR の一覧は、この TUI には入れません。

## 使い方

```
versteck-remote-tui                  # 端末から: メニュー（TUI）
versteck-remote-tui status           # 状態の一覧を数行で
versteck-remote-tui audit --limit 5  # 監査ログを新しい順に 5 件（既定 20）
versteck-remote-tui version          # 版とインターフェースの版
versteck-remote-tui help             # 使い方
```

入口は `bin/versteck-remote-tui` の 1 本で、次の順に振り分けます。

1. `SSH_ORIGINAL_COMMAND` が空でなければ、許可した形（`status` / `audit` / `audit --limit N` / `version` / `help`）と文字列ごと照合し、一致したときだけ同じテキストを返します。eval もシェルへの受け渡しもしません。許可外は終了コード 2 です。
2. 引数があれば、テキストを返します。
3. 標準入力と標準出力がどちらも端末なら、メニューを出します。
4. それ以外（端末でない）は使い方のテキストを返します。

テキストの出力は人が読むためのものです。`--json` は付けません。機械が読むなら、バックエンドを直接使ってください。

### 終了コード（テキストの呼び出し）

| コード | 意味 |
|---|---|
| 0 | 成功 |
| 1 | 予期しない失敗（バックエンドの 2 やその他の失敗も含む） |
| 2 | 使い方の誤り（知らない引数・許可外の `SSH_ORIGINAL_COMMAND`・設定の誤り） |
| 3 | 対象が無い（バックエンドの 3） |
| 4 | 取得できない（バックエンドの 4、認証できない、バックエンドが無い・版が合わない） |

### 環境変数

| 変数 | 既定 | 意味 |
|---|---|---|
| `VERSTECK_TUI_BACKEND` | `/usr/local/sbin/versteck-ctl` | バックエンドのパス |
| `VERSTECK_TUI_SUDO` | `auto` | `never` にすると sudo を付けずに呼びます（テストと root で動かすとき用） |
| `VERSTECK_TUI_SUDO_REFRESH` | `60` | B の方式で sudo の期限を延ばす間隔（秒） |
| `VERSTECK_REMOTE_TUI_SKIP` | なし | 「シェルへ降りる」で TUI が `1` にします。呼び出し側がこれを見て、メニューを出し直さないようにします |

## 認証（A と B）

admin は管理ユーザー `versteck-admin` で入ります。このユーザーは Ansible の入口でもあり、sudo にはパスワードが要ります。TUI は起動時に `sudo -n <バックエンド> interface-version` を試し、方式を決めます。

- **A**: sudo -n が通った場合です。versteck 側の sudoers で、バックエンドの決まった引数の形だけがパスワードなしになっています。鍵のログインだけで動きます。
- **B**: A が通らなかった場合です。`sudo -v` でパスワードを 1 回だけ聞き、背景で `sudo -n -v` を 60 秒ごとに呼んで期限を延ばします。TUI の終了（EXIT・INT・TERM）と「シェルへ降りる」で、この更新を止めます。

どちらの方式でも、バックエンドは `sudo -n` で呼びます。パスワードを聞くのは起動時の 1 回だけです。`sudo -v` に失敗したら理由を出し、シェルへ降ります。sudoers の例と、`stop *` のようなワイルドカードの危うさは [docs/interface.md](docs/interface.md) にあります。

## 起動の仕方は versteck 側が決める

ログイン時にメニューを出すか、鍵の `command=` で縛るかは versteck 側が決めます。この TUI は ForceCommand が付かない前提で作っています。

`~/.profile` から呼ぶ場合の例です。

```sh
# ~/.profile（例）
if [ -z "${VERSTECK_REMOTE_TUI_SKIP:-}" ] && [ -t 0 ] && [ -t 1 ] \
   && command -v versteck-remote-tui >/dev/null 2>&1; then
  exec versteck-remote-tui
fi
```

- 「シェルへ降りる」を選ぶと、TUI は `VERSTECK_REMOTE_TUI_SKIP=1` を設定してから `exec bash -l` します。`bash -l` はもう一度 `~/.profile` を読みますが、この目印があるのでメニューは出ず、繰り返しになりません。
- gum や jq が無い、sudo の確認に失敗した、のようにメニューを出せないときも、TUI は同じ目印を立ててシェルへ降ります。上の例のように `exec` で呼んでも、入れなくなることはありません。メニューの「終了」を選ぶと、`exec` で呼んだ場合は SSH の接続が終わります。
- `bash -l` は `~/.bash_profile` があるとそちらを先に読み、`~/.profile` を読みません。目印を見る処理は、実際に読まれるファイルに置いてください。
- `ssh example-vm status` のように端末なしでコマンドを渡した場合、bash は `~/.profile` を読みません。鍵の `command="versteck-remote-tui"` で縛る場合は、`SSH_ORIGINAL_COMMAND` の照合（上の「使い方」）が効きます。

## 依存と gum の版

- bash・gum・jq・sudo を使います。テストは bats、静的検査は shellcheck です。
- **gum は Ubuntu 26.04 の apt にある 0.17.0 を対象にします。上流の 2.x は使いません。** versteck の Ansible が apt だけで入れられるようにし、外部の apt リポジトリや単体のバイナリを増やさないためです。
- 使う部品は gum 0.14 以降にある `choose` / `confirm` / `filter` / `pager` / `format` / `style` だけです（`input` と `spin` は今は使っていません）。2.x にしかない機能は使いません。手元のテストは Debian 13 の apt の gum 0.14.4 で回しています。

## 入れ方

```sh
make install PREFIX=/usr/local DESTDIR=
```

`$(PREFIX)/bin/versteck-remote-tui`、`$(PREFIX)/lib/versteck-remote-tui/*.sh`、`$(PREFIX)/share/doc/versteck-remote-tui/` に置きます。bin は自分の場所から `../lib/versteck-remote-tui` を探します。

## リリースの出し方

- タグは `vX.Y.Z`（semver）です。タグを push すると GitHub Actions がテストを回し、`versteck-remote-tui-vX.Y.Z.tar.gz` と `SHA256SUMS` を作って GitHub Release に付けます。
- tar.gz の中身は `versteck-remote-tui-vX.Y.Z/` の下の `bin/`・`lib/`・`docs/`・`LICENSE`・`README.md` です。`lib/versteck-remote-tui/version.sh` にはタグの版が書き込まれます。
- 手元で同じものを作るときは `make dist VERSION=X.Y.Z` です（`v` は付けません）。
- versteck の Ansible は、**タグの URL と SHA256 を固定して**取ってきます。同じタグを付け直さないでください。直すときは新しいタグを切ります。

### 版の決まり

- TUI の版とインターフェースの版は別々に数えます。`versteck-remote-tui version` は両方を出します（例 `versteck-remote-tui 1.0.0 (interface 1)`）。
- TUI は自分が期待するインターフェースの版と一致しないバックエンドでは動きません。
- インターフェースの版を上げる変更（古いバックエンドでは動かなくなる変更）は、TUI のメジャーを上げます。
- バックエンドに新しい項目を求めずに済む機能の追加はマイナー、直しはパッチです。

## 開発

テストはすべてコンテナの中で回します。手元に gum・bats・jq を入れません。

```sh
make test                              # ubuntu:26.04 を土台に Dockerfile.test を作って make check
make test TEST_BASE=<手元の image>     # 土台を差し替える
```

- `make check` は shellcheck と bats を走らせます（CI もコンテナの中でこれを呼びます）。
- 対話の画面は PATH の先頭に置いた偽の `gum`（引数を記録し、決めた答えを返す）と偽の `sudo`・偽のバックエンド（`tests/fixtures/`）で流れを試します。本物の gum は非対話で動く `gum format` と `gum style` の煙試験だけに使います。
- gum を呼ぶ部分（`vrt_screen_*`）と、JSON の整形・絞り込みなどの純粋な処理（`vrt_format_status_text`・`vrt_audit_filter` など）を分け、後者を bats で直接試します。

## ライセンス

Apache License 2.0（[LICENSE](LICENSE)）
