# shellcheck shell=bash
# 監査ログ。絞り込みと整形は jq で TUI 側が行う（gum を呼ばない純粋な処理）

VRT_AUDIT_LIMIT=200

# vrt_audit_filter [--failed] [--agent NAME]
# 標準入力の JSON Lines を読み、JSON の配列を新しい順で出す。JSON でない行は飛ばす
#   --failed : result が ok でないもの（denied・error・欠け）だけ
#   --agent  : agent が NAME と一致するものだけ
vrt_audit_filter() {
  local failed=false agent=""
  while (($#)); do
    case $1 in
      --failed) failed=true ;;
      --agent)
        agent=${2-}
        shift
        ;;
      *) return 2 ;;
    esac
    shift
  done
  # --agent は、選択肢に出した名前（vrt_audit_agents が clean したもの）と同じ形で比べる。
  # 並びは time の文字列の新しい順。time が文字列でない・無い記録は末尾に回す
  jq -nR --argjson failed "$failed" --arg agent "$agent" "$VRT_JQ_CLEAN"'
    [inputs | fromjson? | select(type == "object")]
    | map(select(($failed | not) or (.result != "ok")))
    | map(select($agent == "" or ((.agent | type) == "string" and (.agent | clean) == $agent)))
    | sort_by([(.time | type) == "string", (.time | if type == "string" then . else "" end)])
    | reverse'
}

# vrt_audit_filter の配列を 1 件 1 行にする: 時刻  結果  エージェント  コマンド  詳細
vrt_audit_format() {
  jq -r "$VRT_JQ_CLEAN"'
    def f($v): if $v == null then "?" else ($v | clean) end;
    .[] | "\(f(.time))  \(f(.result))  \(f(.agent))  \(f(.command))  \(f(.detail // ""))"'
}

# 標準入力の JSON Lines に出てくるエージェント名を重複なしで並べる
vrt_audit_agents() {
  jq -nR -r "$VRT_JQ_CLEAN"'
    [inputs | fromjson? | select(type == "object") | .agent | strings | clean] | unique | .[]'
}

vrt_screen_audit() {
  local data rc mode agent text
  local -a args
  data=$(vrt_backend audit --json --limit "$VRT_AUDIT_LIMIT")
  rc=$?
  if ((rc != 0)); then
    vrt_ui_error "$(vrt_backend_error_message "$rc")"
    return 0
  fi
  while :; do
    mode=$(vrt_ui_choose --header="Audit log (latest $VRT_AUDIT_LIMIT entries, newest first)" -- \
      "All" "Failures only" "Filter by agent" "Back") || return 0
    case $mode in
      "All") args=() ;;
      "Failures only") args=(--failed) ;;
      "Filter by agent")
        agent=$(printf '%s\n' "$data" | vrt_audit_agents | gum filter --placeholder "Agent name") || continue
        args=(--agent "$agent")
        ;;
      *) return 0 ;;
    esac
    text=$(printf '%s\n' "$data" | vrt_audit_filter "${args[@]}" | vrt_audit_format)
    [[ -n $text ]] || text="No matching entries."
    printf 'Audit log: %s\nTime  Result  Agent  Command  Detail\n\n%s\n' "$mode${agent:+ ($agent)}" "$text" | gum pager
    agent=""
  done
}
