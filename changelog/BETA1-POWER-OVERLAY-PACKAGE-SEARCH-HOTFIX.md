# RusticQ Beta 1 — Overlay power menu & package search hotfix

Base: `release-full.zip` from the three-provider search + floating-power build.

## Power menu

- Restores the **original Quickshell `PanelWindow`** with `WlrLayer.Overlay`, `HyprlandFocusGrab`, full-screen scrim, and a centered floating-looking card.
- Uses `Store.powerScreen`, which is already set to the invoking bar/shortcut's monitor. The overlay appears over the currently visible workspace on that monitor.
- Preserves the mouse/keyboard navigation (`↑`, `↓`, `1`–`6`, Enter, Escape) and explicit confirmation before actions.
- The previous floating window helper remains present for source-compatibility, but the power menu no longer calls it.

## Package search (Pacman, Yay/AUR, Flatpak)

- Fixes human-readable CLI parsing, ANSI color stripping, installed markers, two-line description formats, and Flatpak's truncated IDs with `:full` columns.
- Uses Yay's normal `yay -Ss` CLI search and filters repo items out so AUR results can be found the same way as in a terminal.
- Keeps Flatpak results even when its installed-app inventory request times out.
- Splits queries per provider, matches async results by the **exact original query**, queues the latest query when a previous process is still running, and always clears a provider's loading state if its process exits without parseable output.
- Shows per-provider loading/failure/result states and a useful empty-results explanation.

## Validation

`python3 tools/test_beta1_package_search_hotfix.py` exercises the real CLI parser with representative Pacman, colorized Yay/AUR, and Flatpak outputs; all provider commands are mocked and no installation is performed. Offline regression tests are included, but the user's live Arch/Yay/Flatpak CLI, Quickshell QML compiler and Hyprland require on-device verification.

## Installation

Extract the patch ZIP directly into the **parent of** `quickshell`, for example `unzip -o rusticq-beta1-power-overlay-search-hotfix-patch.zip -d ~/dev`. The full ZIP also contains `quickshell/` at the archive root.
