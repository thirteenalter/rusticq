# Beta 1 — Shell Menu Bar keyboard navigation

The **File / Edit / View / Share / Shell / Tools** bar is RusticQ's Shell Menu Bar.
The window displayed below it is a menu popover. It is not an external
application's global menu.

When a menu is open and focused:

- `Left` / `Right`: switch to the preceding / next enabled category (wrap).
- `Up` / `Down`: highlight the preceding / next action (wrap).
- `Enter` or `Space`: run the highlighted action, using the existing action handler.
- `Escape`: close the popover without running an action.

Mouse selection and keyboard selection share the same highlighted state.
Long menus scroll to reveal the highlighted action. Selecting a different
category synchronizes with the bar's menu-section state and resizes the popup,
so the Share section has room for its additional actions.

The popover requests keyboard focus only while displaying a menu. No new
system-wide hotkeys, Hyprland bindings, or background processes are installed.

Tests: `python3 tools/test_menu_bar_keyboard.py` and
`python3 tools/verify-static.py`.
