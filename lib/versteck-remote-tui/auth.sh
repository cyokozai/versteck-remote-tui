# shellcheck shell=bash
# 認証の方式の判定と、B の方式での sudo の更新。
#   A    : sudoers でバックエンドの決まった引数だけがパスワードなし。sudo -k -n（期限を無視）でも通る
#   B    : sudo -v で 1 回だけパスワードを聞き、背景で sudo -n -v を一定間隔で呼んで期限を延ばす。
#          間隔（VERSTECK_TUI_SUDO_REFRESH）は sudo の timestamp_timeout より短くする
#   none : VERSTECK_TUI_SUDO=never。sudo を付けない（テストと root で動かすとき）

VRT_AUTH_MODE=""
VRT_AUTH_ERROR=""
VRT_KEEPALIVE_PID=""

vrt_auth_label() {
  case $VRT_AUTH_MODE in
    A) echo "認証: A（鍵のログインのみ・sudoers で許可）" ;;
    B) echo "認証: B（sudo のパスワード・${VERSTECK_TUI_SUDO_REFRESH:-60} 秒ごとに更新）" ;;
    *) echo "認証: sudo なし" ;;
  esac
}

# vrt_auth_init <tui|text>
#   tui  : 端末で対話。B なら sudo -v を 1 回聞き、背景の更新を始める
#   text : 端末があれば sudo -v を聞くが更新はしない。端末が無ければ sudo -n だけ
# 戻り値: 0 成功 / 2 設定の誤り / 4 使えない（VRT_AUTH_ERROR に理由）
vrt_auth_init() {
  local purpose=${1:-tui} be
  VRT_AUTH_ERROR=""
  if [[ ! ${VERSTECK_TUI_SUDO_REFRESH:-60} =~ ^[1-9][0-9]*$ ]]; then
    VRT_AUTH_ERROR="VERSTECK_TUI_SUDO_REFRESH の値が不正です: ${VERSTECK_TUI_SUDO_REFRESH}（1 以上の整数の秒。sudo の timestamp_timeout より短くする）"
    return 2
  fi
  be=$(vrt_backend_path)
  if [[ ! -e $be ]]; then
    VRT_AUTH_ERROR="バックエンドが見つかりません: $be（versteck 側で入れるものです。VERSTECK_TUI_BACKEND で場所を変えられます）"
    return 4
  fi
  case ${VERSTECK_TUI_SUDO:-auto} in
    never) VRT_AUTH_MODE=none ;;
    auto)
      # -k: この 1 回だけ期限（タイムスタンプ）を無視する。同じ端末で先に sudo を使っていても、
      # sudoers の NOPASSWD で通るときだけ A にする（期限で通ったのを A と取り違えない）
      if sudo -k -n -- "$be" interface-version >/dev/null 2>&1; then
        VRT_AUTH_MODE=A
      elif [[ $purpose == tui ]] || vrt_is_tty; then
        echo "パスワードなしの sudo では動かせないため、sudo のパスワードを 1 回だけ聞きます。" >&2
        if ! sudo -v; then
          VRT_AUTH_ERROR="sudo の確認に失敗しました。パスワードが違うか、このユーザーにバックエンドを動かす権限がありません。"
          return 4
        fi
        VRT_AUTH_MODE=B
        [[ $purpose == tui ]] && vrt_keepalive_start
      else
        VRT_AUTH_ERROR="パスワードなしの sudo でバックエンドを実行できません。端末から対話で起動するか、versteck 側の sudoers を確かめてください。"
        return 4
      fi
      ;;
    *)
      VRT_AUTH_ERROR="VERSTECK_TUI_SUDO の値が不正です: ${VERSTECK_TUI_SUDO}（auto か never）"
      return 2
      ;;
  esac
  vrt_check_interface
}

# バックエンドのインターフェースの版が、この TUI が期待する版と同じかを確かめる
vrt_check_interface() {
  local out rc
  out=$(vrt_backend interface-version 2>/dev/null)
  rc=$?
  if ((rc != 0)); then
    VRT_AUTH_ERROR="バックエンドの版を確かめられません。$(vrt_backend_error_message "$rc")"
    return 4
  fi
  if ! printf '%s' "$out" | jq -e --argjson v "$VRT_INTERFACE_VERSION" \
    'type == "object" and .interface == $v' >/dev/null 2>&1; then
    VRT_AUTH_ERROR="バックエンドのインターフェースの版が合いません（この TUI が期待する版: $VRT_INTERFACE_VERSION、返った値: $(printf '%s' "$out" | head -c 200 | vrt_sanitize_text)）"
    return 4
  fi
}

# 背景で sudo の期限を延ばし続ける。TUI の終了（EXIT/INT/TERM）で止める。
# trap が走らない終わり方（SIGKILL など）に備え、親（TUI）がいなくなったら自分で終わる
vrt_keepalive_start() {
  local interval=${VERSTECK_TUI_SUDO_REFRESH:-60} parent=$$
  (
    sp=""
    trap 'if [[ -n $sp ]]; then kill "$sp" 2>/dev/null; fi; exit 0' TERM
    while :; do
      sleep "$interval" &
      sp=$!
      wait "$sp"
      sp=""
      kill -0 "$parent" 2>/dev/null || exit 0
      sudo -n -v >/dev/null 2>&1 || exit 0
    done
  ) &
  VRT_KEEPALIVE_PID=$!
  trap 'vrt_auth_cleanup' EXIT
  trap 'vrt_auth_cleanup; exit 130' INT
  trap 'vrt_auth_cleanup; exit 143' TERM
}

vrt_auth_cleanup() {
  if [[ -n $VRT_KEEPALIVE_PID ]]; then
    kill -TERM "$VRT_KEEPALIVE_PID" 2>/dev/null
    wait "$VRT_KEEPALIVE_PID" 2>/dev/null
    VRT_KEEPALIVE_PID=""
  fi
  return 0
}
