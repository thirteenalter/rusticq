# RusticQ Alpha 4 RC4 — Hyprland keybindings and permanent Omarchy replacement

RC4 introduces **Settings → Integration**. Nothing changes in the system until
an explicit user click and confirmation. No commands are run with `sudo` and
no `/usr/share/omarchy` files are edited.

## Keyboard shortcut editor

- Select a binding such as `SUPER + SHIFT + R` and an action: Settings,
  App Launcher, Quick Control, AI Workspace, or System Monitor.
- **Apply shortcut** adds or updates a key/action mapping in a single managed
  block in `~/.config/hypr/bindings.lua` using `o.rebind(...)`. Multiple distinct
  shortcuts are supported. Existing Omarchy bindings
  on that combination are replaced (not duplicated). Inspect existing bindings
  with `omarchy menu keybindings --print` before overriding them.
- **Restore shortcut** deletes **all** RusticQ-managed overrides and keeps unrelated user Lua
  lines. The original file is also backed up under
  `~/.local/state/rusticq/integration/`.
- Quickshell `IpcHandler` receives shortcut requests in the running shell;
  pressing the key **does not launch a second RusticQ instance**.

## Permanent desktop integration

Use **Settings → Integration → Make RusticQ permanent**. The UI requires typing
`ENABLE RUSTICQ` before applying.

The installer supports only recognized **Omarchy Quattro / Hyprland Lua** layouts.
It refuses unknown config formats rather than risking the desktop. A successful
install:

1. Backs up `~/.config/hypr/hyprland.lua`, `bindings.lua`,
   Omarchy's `default/hypr/autostart.lua`, and `~/.config/omarchy/shell.json`
   (if present), under `~/.local/state/rusticq/integration/backup/`.
2. Copies the RusticQ source into `~/.local/share/rusticq/shell/` for a stable,
   user-owned installation.
3. Creates a private copy of **the current Omarchy autostart script**, changing
   only the command that launches Omarchy Shell. Other commands (environment,
   power profiles, monitor watch, and hooks) are retained verbatim.
4. Intercepts the Omarchy autostart module via a managed Lua block in the user
   `hyprland.lua`. No system-owned package files are modified.
5. Starts RusticQ **at the next login**, not in the middle of the current session.

This replaces **Omarchy Shell**, not the full Omarchy distribution or Hyprland.
Omarchy Shell's menu, notification server, polkit UI, lock screen integration,
clipboard/panel plugins, etc. may not be replaced by RusticQ. Review that
risk before enabling.

### Revert from Settings

Type `RESTORE OMARCHY` and click **Restore Omarchy shell**. Logout and log in
again. Managed shell-startup and shortcut overrides are reverted. The installed
shell directory is archived, not deleted, so personal settings are retained.

### Emergency restore (if RusticQ cannot open)

Open a TTY (`Ctrl+Alt+F3`), log in as the regular user, and run:

```sh
python3 ~/.local/share/rusticq/shell/scripts/rustiq-desktop-integration.py \
  revert --confirm 'RESTORE OMARCHY'
```

Return to your graphical session or log out/in to restore the original
Omarchy Shell. Backups remain at
`~/.local/state/rusticq/integration/backup/`.

### Notes and limitations

- Installed RusticQ is a snapshot copied into `~/.local/share/rusticq/shell`.
  Later changes in the development directory are **not automatically copied**
  into the permanent install; revert and reinstall to refresh safely.
- Installer is conservative: symlinked or unsupported user config files and
  unknown autostart patterns are rejected.
- Omarchy updates that change its default autostart structure require
  integration review. Avoid running duplicate shell instances.
- The next-login startup behavior and Hyprland Lua runtime must be tested on
  the user's actual Omarchy machine; offline tests cannot guarantee them.

## Files

- `scripts/rustiq-desktop-integration.py`
- `modules/settings/pages/SettingsIntegrationPage.qml`
- `modules/settings/SettingsWindow.qml`
- `shell.qml`
- `modules/settings/pages/SettingsAboutPage.qml`
- `tools/test_rc4_desktop_integration.py`

## References

- https://omarchy.org/manual/dotfiles/
- https://github.com/omacom/omarchy/blob/quattro/default/agents/skills/omarchy/hyprland.md
- https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/IpcHandler/
