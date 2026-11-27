# shellcheck shell=bash
# バックエンドの呼び出し・セッション名の検査・終了コードの文言（gum を呼ばない純粋な部分）

VRT_DEFAULT_BACKEND=/usr/local/sbin/versteck-ctl
# docs/interface.md の「セッション名」と同じ形。先頭は英数字（--all などの引数と紛れないように）
VRT_SESSION_RE='^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'

vrt_backend_path() {
  printf '%s\n' "${VERSTECK_TUI_BACKEND:-$VRT_DEFAULT_BACKEND}"
}

vrt_have_command() {
  command -v "$1" >/dev/null 2>&1
}

vrt_valid_session_name() {
  [[ $1 =~ $VRT_SESSION_RE ]]
}

# バックエンドを呼ぶ。認証の方式が A / B なら sudo -n を付ける（パスワードを聞くのは起動時の 1 回だけ）
vrt_backend() {
  local be
  be=$(vrt_backend_path)
  case ${VRT_AUTH_MODE:-none} in
    A | B) sudo -n -- "$be" "$@" ;;
    *) "$be" "$@" ;;
  esac
}

# バックエンドの終了コードを人が読む文にする
vrt_backend_error_message() {
  local rc=$1
  case $rc in
    2) echo "バックエンドが使い方の誤りを返しました（終了コード 2）。TUI とバックエンドの版が合っていない可能性があります。" ;;
    3) echo "対象が見つかりません（終了コード 3）。セッションがすでに終わった可能性があります。" ;;
    4) echo "情報を取得できませんでした（終了コード 4）。バックエンドの下回りが失敗しています。" ;;
    126 | 127) echo "バックエンドを実行できません（終了コード $rc）: $(vrt_backend_path)" ;;
    *) echo "予期しない失敗です（終了コード $rc）。" ;;
  esac
}

# テキストの呼び出しが返す終了コード。3 と 4 はそのまま、それ以外の失敗は 1
# （バックエンドの 2 は呼び出し側の誤りではないので、TUI の 2 とは分ける）
vrt_text_exit_code() {
  case $1 in
    3 | 4) echo "$1" ;;
    *) echo 1 ;;
  esac
}

# 端末の制御列を落とす（改行とタブは残す）。バックエンドの出力をそのまま端末に流さないため
vrt_sanitize_text() {
  LC_ALL=C tr -d '\000-\010\013-\037\177'
}

# jq の中で使う、制御文字を ? に置き換える関数
# shellcheck disable=SC2016  # jq の式なので展開しない
VRT_JQ_CLEAN='def clean: tostring | gsub("[\u0000-\u001f\u007f]"; "?");'
