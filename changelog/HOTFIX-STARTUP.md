# Hotfix: Bar.qml cannot assign to non-existent property targetScreen

## Log reported

```text
ERROR: Failed to load configuration
caused by @shell.qml[10:9]: Type Bar unavailable
caused by @modules/main/Bar.qml[36:23]: Cannot assign to non-existent property "targetScreen"
```

## Change

`modules/main/Bar.qml`: Removed the custom `targetScreen` assignment on `PowerButton`. The right-hand toggle is now an inline Gruvbox-styled `Rectangle` plus `MouseArea`, and directly updates `Store.sidebarScreen` and `Store.sidebarVisible`. Other files are left unchanged except this note and README.

## Applying

Extract the ZIP, back up your current config and copy *all* of the `quickshell/` directory into your existing configuration, or replace only `modules/main/Bar.qml` if you want this one-line startup issue fixed with the smallest change.

```bash
# example: from your project directory, after extracting ZIP
cp modules/main/Bar.qml /home/ryznxx/dev/quickshell/modules/main/Bar.qml
qs -p /home/ryznxx/dev/quickshell
```

Do not merge old and new versions of Bar.qml, or keep duplicate QML components at different paths. If you still see the same error at line 36, verify the absolute file on disk is the new one (`grep -n targetScreen /home/ryznxx/dev/quickshell/modules/main/Bar.qml` should return no matches).

## Limitations

This is a targeted startup hotfix. It passes static checks, but runtime can only be validated in your Wayland/Hyprland environment. Report any next load error with its line number so the chain can be resolved.
