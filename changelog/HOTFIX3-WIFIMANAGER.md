# Hotfix 3 — WifiManager is not a type (Quickshell 0.3.1)

## Runtime error reported

```text
Type BarWrapper unavailable
Type BarMain unavailable
Type BarWifi unavailable
@modules/bar/BarWifi.qml[20:5]: WifiManager is not a type
```

## Root cause

`modules/bar/BarWifi.qml` instantiates `WifiManager { id: manager }`,
but `services/qmldir` declared only singleton services. Once a directory has
`qmldir`, custom components should be declared there explicitly so QML
can resolve them through a directory import.

## Fix

Added this **non-singleton** type entry to `services/qmldir`:

```text
WifiManager 1.0 WifiManager.qml
```

This is deliberately not `singleton WifiManager` because `BarWifi.qml`
creates an instance with `WifiManager { ... }`. No changes to color tokens,
fonts, or layout were needed for this fix.

## Quick test

From the directory containing the included `quickshell` folder:

```sh
qs -p ./quickshell
qs log -f
```

If you prefer a one-file patch for the existing installation, copy only
`quickshell/services/qmldir` over your current `services/qmldir` file.

## Validation

- ZIP integrity checked
- QML directory type registration checked
- Local imports and paths checked
- Installed Quickshell 0.3.1 in a Hyprland session was NOT available for runtime testing

Reference: https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/Networking/
