# RusticQ Alpha 2 — standalone indicator widgets

Baseline: Quickshell **0.3.1**, derived from `rustiq-alpha-1.zip`.

## Fixed: indicator mini-popup can collapse into an empty box

Previously each mini popup reused `BarWifi`, `BarBluetooth`, and `BarBattery` with `expanded: true`, but the accordion header was still clickable. Clicking it changed the local state to `false`; the content vanished while `PopupWindow.implicitHeight` stayed the same, leaving a mostly empty window.

Now those cards take a **`standalone`** property. In a mini-popup it is `true` and forces content visible, hides the chevron and disables the header's click handler. Inside the full Quick Control it remains `false`, preserving the usual expand/collapse behavior. The popup's `Loader` also fills its parent explicitly rather than relying on nested layout attached properties. Each card remains scrollable where needed.

### Header icon

The Quick Control trigger in the bar and the icon at the top-left of the Quick Control panel now use **`stat_minus_1` (U+E69B)** from the bundled `assets/google.ttf`. The optional `PowerButton.qml` uses it too. The left-hand **Arch AI** launcher intentionally retains its own icon: these are two different functions.

## Smoke test on the desktop

Run `qs -p ./quickshell` from the parent folder. Click Wi-Fi, Bluetooth and Battery icons in the bar. Each popup should show its content immediately, without a chevron. Clicking the header should not collapse anything; clicking outside should close it. Scrolling through Wi-Fi networks and Bluetooth devices should still work. Now open full Quick Control and confirm each section still has a clickable chevron and can be collapsed/expanded. Confirm the Quick Control bar trigger and the Quick Control header have the new icon.

If the popup overflows on a small screen or overlaps the top bar, include the display scale/resolution and `qs log -f` when reporting the issue.

## Validation

`python tools/verify-static.py`

`python tools/test_rustiq_alpha2.py`

`python tools/test_rustiq_alpha1.py`

`python tools/test_hotfix10.py`

`python tools/test_hotfix9.py`

Static checks do **not** replace testing QML/Wayland rendering on an installed Quickshell desktop. No cloud credentials should be placed in the archive.
