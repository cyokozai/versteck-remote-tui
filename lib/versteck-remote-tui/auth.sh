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
    A) echo "auth: A (SSH key only, sudoers)" ;;
    B) echo "auth: B (sudo password, refreshed every ${VERSTECK_TUI_SUDO_REFRESH:-60} s)" ;;
    *) echo "auth: no sudo" ;;
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
    VRT_AUTH_ERROR="Invalid value for VERSTECK_TUI_SUDO_REFRESH: ${VERSTECK_TUI_SUDO_REFRESH} (an integer of 1 or more, in seconds; keep it shorter than sudo timestamp_timeout)"
    return 2
  fi
  be=$(vrt_backend_path)
  if [[ ! -e $be ]]; then
    VRT_AUTH_ERROR="Backend not found: $be (it is installed on the versteck side; set VERSTECK_TUI_BACKEND to change the location)"
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
        echo "Passwordless sudo is not available, so the sudo password is asked once." >&2
        if ! sudo -v; then
          VRT_AUTH_ERROR="sudo check failed. The password is wrong, or this user is not allowed to run the backend."
          return 4
        fi
        VRT_AUTH_MODE=B
        [[ $purpose == tui ]] && vrt_keepalive_start
      else
        VRT_AUTH_ERROR="Cannot run the backend with passwordless sudo. Start it interactively from a terminal, or check sudoers on the versteck side."
        return 4
      fi
      ;;
    *)
      VRT_AUTH_ERROR="Invalid value for VERSTECK_TUI_SUDO: ${VERSTECK_TUI_SUDO} (auto or never)"
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
    VRT_AUTH_ERROR="Cannot check the backend version. $(vrt_backend_error_message "$rc")"
    return 4
  fi
  if ! printf '%s' "$out" | jq -e --argjson v "$VRT_INTERFACE_VERSION" \
    'type == "object" and .interface == $v' >/dev/null 2>&1; then
    VRT_AUTH_ERROR="Backend interface version mismatch (this TUI expects: $VRT_INTERFACE_VERSION, got: $(printf '%s' "$out" | head -c 200 | vrt_sanitize_text))"
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
