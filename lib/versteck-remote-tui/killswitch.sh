# shellcheck shell=bash
# 止め方の手順。正本の文書は versteck 側にあり、TUI はバックエンドの kill-switches を読んで見せるだけ

vrt_screen_kill_switches() {
  local md rc
  md=$(vrt_backend kill-switches)
  rc=$?
  if ((rc != 0)); then
    vrt_ui_error "$(vrt_backend_error_message "$rc")"
    return 0
  fi
  printf '%s\n' "$md" | vrt_sanitize_text | gum format | gum pager
}
