# RusticQ — Startup syntax correction (no release or version increment)

This is a maintenance patch for the existing RusticQ Alpha 3 RC3 source. It does **not** introduce an RC4 or a new numbered release.

## Crash addressed

Reported:

```
@shell.qml[29:9]: Type SettingsWindow unavailable
@modules/settings/SettingsWindow.qml[728:29]: Type BarMonitors unavailable
@modules/bar/BarMonitors.qml[282:111]: Unexpected token `;'
```

Root cause: `modules/bar/BarMonitors.qml` placed a semicolon between two QML child object declarations in a RowLayout (`Icon { ... }; Text { ... }`). QML object declarations are not semicolon-separated JavaScript expressions. These children have been written on separate lines without the invalid separator.

## Source changes

- `modules/bar/BarMonitors.qml`: correct sibling QML syntax for the nwg-displays launch row; behavior and theme unchanged.
- `tools/verify-static.py`: scan all QML files for invalid semicolons between neighboring child object declarations in addition to previous balance/import checks.
- `tools/test_startup_syntax_regression.py`: confirm the check rejects the original type of syntax error when reintroduced deliberately in an isolated temporary copy.

No other application source files were changed. The label inside Settings and project version remain unchanged.

## How to apply

**Smallest change**: Copy the corrected `modules/bar/BarMonitors.qml` file onto the same path within your existing RusticQ config. This preserves all preferences and unrelated local edits.

Alternatively, extract the full archive to a new directory and start it there. If replacing your existing config, back up `user-settings.json` and any custom source edits first. This archive includes the original default `user-settings.json` from the input release.

```
qs -p /path/to/quickshell
```

To validate the source locally:

```
python3 /path/to/quickshell/tools/verify-static.py
python3 /path/to/quickshell/tools/test_startup_syntax_regression.py
```

## Verification scope

- All 57 QML files passed source-level structural/import checks.
- The new regression test confirmed that the original malformed separator is rejected.
- Existing source-only test scripts passed; Python and shell scripts passed compilation/syntax checks.
- A test requiring the `qs` executable and a desktop session could not run here. Thus successful startup in your Quickshell 0.3.1/Hyprland session still needs confirmation.

If a new startup error occurs, please share the complete `qs -p ...` message including filename and line number. Nothing in these checks guarantees full QML parsing or live desktop behavior.
