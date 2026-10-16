#!/bin/sh
# Local-only Wayland screen capture, no network action.
set -eu
mode=${1:-}
folder="${XDG_PICTURES_DIR:-${HOME:?}/Pictures}/Screenshots"
case "$mode" in
  full|region)
    command -v grim >/dev/null 2>&1 || { printf '%s\n' 'RusticQ: grim is required' >&2; exit 127; }
    if [ "$mode" = region ]; then
      command -v slurp >/dev/null 2>&1 || { printf '%s\n' 'RusticQ: slurp is required' >&2; exit 127; }
      geometry=$(slurp) || exit 1
      [ -n "$geometry" ] || exit 1
    fi
    mkdir -p "$folder"
    output="$folder/rustiq-$(date +%Y%m%d-%H%M%S).png"
    if [ "$mode" = region ]; then grim -g "$geometry" "$output"; else grim "$output"; fi
    printf '%s\n' "Saved $output"
    ;;
  folder)
    mkdir -p "$folder"
    xdg-open "$folder"
    ;;
  *) printf '%s\n' 'Usage: rustiq-capture.sh full|region|folder' >&2; exit 2 ;;
esac
