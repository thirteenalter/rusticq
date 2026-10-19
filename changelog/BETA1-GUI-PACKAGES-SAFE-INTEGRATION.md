# RusticQ Beta 1 — GUI package manager and full pre-install backups

- Installed Apps install/remove now uses `/usr/bin/pkexec /usr/bin/pacman` in the existing QML Settings Process; no terminal is launched. Actual exit status, package state and diagnostic output returned to UI.
- Integration Dependencies install and remove *optional* allowlisted packages with explicit confirmation; core packages cannot be removed in this panel. Polkit dialog is the only auth UI; no sudo-password collection in QML.
- Omarchy package guard is preserved; unsupported transactions fail with a displayed error rather than circumventing distribution policy. Arch installs may upgrade the system as part of supported `-Syu`.
- Original default Omarchy Lua tree is retained; additionally saves `~/.config/hypr`, `~/.config/omarchy`, and `~/.config/quickshell` with symlink-safe copies, SHA-256 manifest, private permissions, and fail-closed bounds.
- Permanent enable requires verified originals. Revert verifies originals before any mutation and saves pre-revert managed config copies; unrelated user config is not overwritten. Existing legacy backups remain revertible without making false copies of modified configs.
- No installer runs on ZIP extraction; Patch ZIP paths stay underneath `quickshell/`.
- Requires `pkexec`, a working graphical polkit agent and pacman. Actual Hyprland/Polkit desktop session not available in offline build environment; run-time testing is necessary.
