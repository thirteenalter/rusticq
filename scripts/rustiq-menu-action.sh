#!/bin/sh
# RusticQ safe menu action helper. No arbitrary commands or user-provided shell strings.
set -eu
case "${1:-}" in
  file-home) exec xdg-open "$HOME" ;;
  file-downloads) exec xdg-open "$HOME/Downloads" ;;
  file-config) exec xdg-open "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)" ;;
  shell-terminal|shell-monitor)
    term=""
    for candidate in ghostty kitty foot alacritty wezterm konsole xterm; do
      if command -v "$candidate" >/dev/null 2>&1; then term=$candidate; break; fi
    done
    [ -n "$term" ] || { echo "No supported terminal installed" >&2; exit 1; }
    if [ "$1" = shell-terminal ]; then exec "$term"; fi
    monitor=""
    if command -v btop >/dev/null 2>&1; then monitor=btop
    elif command -v htop >/dev/null 2>&1; then monitor=htop
    else echo "Install btop or htop" >&2; exit 1; fi
    case "$term" in
      ghostty|kitty|foot|alacritty|konsole|xterm) exec "$term" -e "$monitor" ;;
      wezterm) exec "$term" start -- "$monitor" ;;
    esac
    ;;
  *) echo "Unknown action" >&2; exit 2 ;;
esac
