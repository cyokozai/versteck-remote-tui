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

# vrt_join <区切り> <語...>: 語を区切りでつなぐ
vrt_join() {
  local sep=$1 out=$2
  shift 2
  while (($#)); do
    out+="$sep$1"
    shift
  done
  printf '%s\n' "$out"
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
    2) echo "The backend reported a usage error (exit code 2). The TUI and the backend may be different versions." ;;
    3) echo "Target not found (exit code 3). The session may have already ended." ;;
    4) echo "Could not get the information (exit code 4). The backend failed internally." ;;
    126 | 127) echo "Cannot run the backend (exit code $rc): $(vrt_backend_path)" ;;
    *) echo "Unexpected failure (exit code $rc)." ;;
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

# 端末の制御列を落とす（改行とタブは残す）。バックエンドの出力をそのまま端末に流さないため。
#   tr  : C0 制御文字と DEL（1 バイト）
#   sed : UTF-8 で 2〜3 バイトになるもの。C1 制御文字（U+0080〜U+009F、U+009B は CSI として働く端末がある）と、
#         文字の向きを変える制御文字（U+061C、U+200E、U+200F、U+202A〜U+202E、U+2066〜U+2069）
#   LC_ALL=C でバイトとして扱う。C2・D8・E2 は UTF-8 の先頭のバイトにしか現れないので、ほかの文字の途中には当たらない
vrt_sanitize_text() {
  LC_ALL=C tr -d '\000-\010\013-\037\177' |
    LC_ALL=C sed -e $'s/\xc2[\x80-\x9f]//g' \
      -e $'s/\xd8\x9c//g' \
      -e $'s/\xe2\x80[\x8e\x8f\xaa-\xae]//g' \
      -e $'s/\xe2\x81[\xa6-\xa9]//g'
}

# jq の中で使う、制御文字を ? に置き換える関数（落とす文字は vrt_sanitize_text と同じ）
# shellcheck disable=SC2016  # jq の式なので展開しない
VRT_JQ_CLEAN='def clean: tostring | gsub("[\u0000-\u001f\u007f-\u009f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]"; "?");'
