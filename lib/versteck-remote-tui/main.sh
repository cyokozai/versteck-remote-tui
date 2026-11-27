# shellcheck shell=bash
# 入口の振り分け。
#   1. SSH_ORIGINAL_COMMAND が空でない → 許可した形だけと照合してテキストを返す（許可外は 2）
#   2. 引数がある                      → テキスト（status / audit / version / help）
#   3. 標準入出力が端末                → TUI
#   4. それ以外                        → 使い方のテキスト

VRT_INTERFACE_VERSION=1
VRT_TEXT_AUDIT_DEFAULT=20
VRT_SSH_COMMAND_RE='^(status|version|help|audit( --limit [1-9][0-9]{0,3})?)$'

vrt_is_tty() {
  [[ -t 0 && -t 1 ]]
}

vrt_usage() {
  cat <<'EOF'
使い方: versteck-remote-tui [status | audit [--limit N] | version | help]

  引数なし（端末から）  メニュー（TUI）を出す
  status                状態の一覧を数行で出す
  audit [--limit N]     監査ログを新しい順に N 件（既定 20、1〜9999）
  version               版とインターフェースの版
  help                  この説明

機械向けの出力（JSON）が要るときは、バックエンド（既定 /usr/local/sbin/versteck-ctl）を直接使ってください。
EOF
}

vrt_main() {
  if [[ -n ${SSH_ORIGINAL_COMMAND:-} ]]; then
    vrt_run_ssh_command "$SSH_ORIGINAL_COMMAND"
    return
  fi
  if (($# > 0)); then
    vrt_run_text "$@"
    return
  fi
  if vrt_is_tty; then
    vrt_tui
    return
  fi
  vrt_usage
}

# SSH_ORIGINAL_COMMAND を許可した形と照合する。eval もシェルへの受け渡しもしない
vrt_run_ssh_command() {
  local cmd=$1
  local -a words
  if [[ ! $cmd =~ $VRT_SSH_COMMAND_RE ]]; then
    echo "許可されていないコマンドです。使えるのは status / audit [--limit N] / version / help だけです。" >&2
    return 2
  fi
  read -r -a words <<<"$cmd"
  vrt_run_text "${words[@]}"
}

vrt_run_text() {
  local sub=$1
  shift
  case $sub in
    version)
      (($# == 0)) || { vrt_usage >&2; return 2; }
      printf 'versteck-remote-tui %s (interface %s)\n' "$VRT_VERSION" "$VRT_INTERFACE_VERSION"
      ;;
    help | -h | --help)
      (($# == 0)) || { vrt_usage >&2; return 2; }
      vrt_usage
      ;;
    status)
      (($# == 0)) || { vrt_usage >&2; return 2; }
      vrt_text_status
      ;;
    audit)
      local limit=$VRT_TEXT_AUDIT_DEFAULT
      if (($# > 0)); then
        if (($# == 2)) && [[ $1 == --limit && $2 =~ ^[1-9][0-9]{0,3}$ ]]; then
          limit=$2
        else
          vrt_usage >&2
          return 2
        fi
      fi
      vrt_text_audit "$limit"
      ;;
    *)
      vrt_usage >&2
      return 2
      ;;
  esac
}

vrt_text_auth() {
  local rc
  vrt_auth_init text
  rc=$?
  if ((rc != 0)); then
    printf '%s\n' "$VRT_AUTH_ERROR" >&2
    return "$rc"
  fi
}

vrt_text_status() {
  local json rc
  vrt_text_auth || return
  json=$(vrt_backend status --json)
  rc=$?
  if ((rc != 0)); then
    vrt_backend_error_message "$rc" >&2
    return "$(vrt_text_exit_code "$rc")"
  fi
  if ! printf '%s\n' "$json" | vrt_format_status_text 2>/dev/null; then
    echo "バックエンドの出力を読めません（status --json が JSON のオブジェクトではありません）。" >&2
    return 4
  fi
}

vrt_text_audit() {
  local limit=$1 data rc
  vrt_text_auth || return
  data=$(vrt_backend audit --json --limit "$limit")
  rc=$?
  if ((rc != 0)); then
    vrt_backend_error_message "$rc" >&2
    return "$(vrt_text_exit_code "$rc")"
  fi
  printf '%s\n' "$data" | vrt_audit_filter | vrt_audit_format
}
