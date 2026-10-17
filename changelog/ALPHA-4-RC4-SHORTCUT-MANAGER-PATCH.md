# RusticQ Alpha 4 RC4 — Shortcut Manager Patch

- Added Settings > Keyboard Shortcuts as a standalone section, with searchable Lua binding inventory.
- Scans the user's `~/.config/hypr/bindings.lua` and Omarchy default Hyprland Lua sources read-only, displaying key, label and origin.
- Choosing an existing binding copies its key combo to the editor.
- Overrides use `hl.unbind(key)` followed by `o.bind(key, label, command)` instead of relying on a potentially unavailable `o.rebind` method.
- Preserved managed block markers, snapshot/restore, error checking and original Omarchy configurations.
- Integration now focuses on permanent startup installation, backups and recovery.
- The inventory is static/best-effort: bindings generated dynamically via functions may not show up. Check `omarchy menu keybindings --print` for effective bindings.

## Safe recovery of RC4 `o.rebind` error

If the user's live `bindings.lua` still contains the older broken managed block, use the original RC4 UI's Restore shortcut action (if accessible) or invoke:

```sh
python3 /path/to/rusticq/scripts/rustiq-desktop-integration.py shortcut-revert
```

Then reapply shortcuts with the patched app. Changes take effect after Hyprland reload, and installation of the shell replacement must be separately confirmed.
