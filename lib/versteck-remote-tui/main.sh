# shellcheck shell=bash
# 入口の振り分け。

VRT_INTERFACE_VERSION=1

vrt_main() {
  case ${1:-} in
    version) printf 'versteck-remote-tui %s (interface %s)\n' "$VRT_VERSION" "$VRT_INTERFACE_VERSION" ;;
  esac
}
