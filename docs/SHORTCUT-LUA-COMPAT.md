# Omarchy Quattro shortcut Lua compatibility

Some installed Omarchy Quattro builds expose `o.bind` and `hl.unbind`, but
have **no `o.rebind`**. Earlier RusticQ releases generated `o.rebind` inside
`~/.config/hypr/bindings.lua`, which caused a Lua configuration error.

This release writes `hl.unbind(combo)` for every managed destination key,
followed by `o.bind(combo, description, command)`. For remapped shortcuts it
unbinds both the original and new combination before binding the new one.
All changes remain isolated in the managed block; original Omarchy defaults and
user-authored Lua lines are not edited. Existing legacy managed blocks are
migrated on the next successful Apply/Restore, using the saved mapping.

Shortcut changes still take a full default-Omarchy and per-change dotfiles
backup, with integrity verification **before** editing. A failed Hyprland
reload/config validation restores the old `bindings.lua` and performs another
reload. Backup snapshots are not deleted by recovery.

## Safe recovery on an existing installation

If `shortcut-revert --action power` says `This action has no override`, no
power mapping exists in RusticQ's current registry. This is expected if the
previous Apply failed before the mapping was committed.

1. Run `hyprctl reload` and `hyprctl configerrors` and confirm there are no
   errors.
2. Install the updated RusticQ patch.
3. Open Settings → Shortcuts → Verify backup. Ensure it succeeds.
4. Choose your intended action and key, then Apply and approve the backup.
5. Re-check `hyprctl configerrors` and inspect the effective keybindings with
   `hyprctl binds -j` or `omarchy menu keybindings --print`.

If a config error persists, inspect the affected `~/.config/hypr/bindings.lua`
line and compare with private backups in
`~/.local/state/rusticq/integration/backup/shortcut-history/`. Do not delete
backups or overwrite the entire Omarchy configuration without checking changes.
