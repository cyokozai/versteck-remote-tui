# shellcheck shell=bash
# 状態の一覧。vrt_format_status_text と vrt_session_names は gum を呼ばない純粋な処理

# status --json の JSON（標準入力）を人が読む行にする。JSON のオブジェクトでなければ失敗する
vrt_format_status_text() {
  jq -r "$VRT_JQ_CLEAN"'
    def str($v): if ($v | type) == "string" and ($v | length) > 0 then ($v | clean) else "不明" end;
    def pick($v; $allowed): if ($v | type) == "string" and any($allowed[]; . == $v) then $v else "unknown" end;
    def human_ja: {"active":"稼働中","inactive":"止まっている","failed":"失敗","unknown":"不明"}[.];
    def ts_ja: {"connected":"つながっている","disconnected":"切れている","unknown":"不明"}[.];
    def detail($o): if ($o | type) == "object" and ($o.detail | type) == "string" and ($o.detail | length) > 0
                    then " " + ($o.detail | clean) else "" end;
    if type != "object" then error("status は JSON のオブジェクトではありません") else . end
    | (.human_entrance | if type == "object" then . else {} end) as $h
    | (.tailscale | if type == "object" then . else {} end) as $t
    | pick($h.state; ["active","inactive","failed","unknown"]) as $hs
    | pick($t.state; ["connected","disconnected","unknown"]) as $ts
    | "ホスト: \(str(.host))",
      "取得時刻: \(str(.generated_at))",
      "人の入口: \($hs | human_ja) (\($hs))\(detail($h))",
      "Tailscale: \($ts | ts_ja) (\($ts))\(detail($t))",
      (if (.disks | type) != "array" or (.disks | length) == 0 then "ディスク: 不明"
       else "ディスク:",
         (.disks[] | if type == "object" then . else {} end
          | (if (.used_percent | type) == "number" then .used_percent else null end) as $p
          | "  \(str(.mount)) \(if $p == null then "?" else "\($p)" end)%\(if $p != null and $p >= 90 then " 残りわずか" else "" end)")
       end),
      (if (.sessions | type) != "array" then "セッション: 不明"
       elif (.sessions | length) == 0 then "セッション: なし"
       else "セッション: \(.sessions | length) 件",
         (.sessions[] | if type == "object" then . else {} end
          | "  \(str(.name)) \(str(.agent)) \(str(.started_at))")
       end)
  '
}

# status --json の JSON（標準入力）から、検査を通るセッション名だけを 1 行ずつ出す
vrt_session_names() {
  local name
  jq -r '.sessions | if type == "array" then .[] else empty end | .name? | strings' |
    while IFS= read -r name; do
      if vrt_valid_session_name "$name"; then printf '%s\n' "$name"; fi
    done
}

# status --json の JSON（標準入力）の sessions の件数（形が合わない名前も数える）。
# JSON でない・sessions が配列でないときは失敗する
vrt_session_total() {
  jq -e '.sessions | if type == "array" then length else error("sessions は配列ではありません") end' 2>/dev/null
}

VRT_SESSIONS_UNREADABLE="セッションの一覧を取得できませんでした（status --json が JSON でないか、sessions が配列になっていません）。"

# vrt_load_sessions <status の JSON>
# VRT_SESSION_NAMES（検査を通る名前）・VRT_SESSION_TOTAL・VRT_SESSION_REJECTED（弾いた件数）を決める。
# 弾いたものがあればその件数を画面に出す。一覧を読めなければ文言を出して非 0
vrt_load_sessions() {
  local json=$1
  VRT_SESSION_NAMES=()
  VRT_SESSION_TOTAL=0
  VRT_SESSION_REJECTED=0
  if ! VRT_SESSION_TOTAL=$(printf '%s\n' "$json" | vrt_session_total); then
    VRT_SESSION_TOTAL=0
    vrt_ui_error "$VRT_SESSIONS_UNREADABLE"
    return 1
  fi
  mapfile -t VRT_SESSION_NAMES < <(printf '%s\n' "$json" | vrt_session_names)
  VRT_SESSION_REJECTED=$((VRT_SESSION_TOTAL - ${#VRT_SESSION_NAMES[@]}))
  if ((VRT_SESSION_REJECTED > 0)); then
    vrt_ui_say "名前の形が合わないセッションが $VRT_SESSION_REJECTED 件あり、一覧に出していません。"
  fi
  return 0
}

# バックエンドから status を取る。失敗したら文言を出して非 0
vrt_fetch_status() {
  local json rc
  json=$(vrt_backend status --json)
  rc=$?
  if ((rc != 0)); then
    vrt_ui_error "$(vrt_backend_error_message "$rc")"
    return "$rc"
  fi
  printf '%s\n' "$json"
}

vrt_screen_status() {
  local json text next
  while :; do
    json=$(vrt_fetch_status) || return 0
    if ! text=$(printf '%s\n' "$json" | vrt_format_status_text 2>/dev/null); then
      vrt_ui_error "バックエンドの出力を読めません（status --json が JSON のオブジェクトではありません）。"
      return 0
    fi
    printf '状態の一覧（取得 %s）\n\n%s\n' "$(date '+%H:%M:%S')" "$text" | gum pager
    next=$(vrt_ui_choose --header="状態の一覧" -- "再読み込み" "戻る") || return 0
    [[ $next == "再読み込み" ]] || return 0
  done
}
