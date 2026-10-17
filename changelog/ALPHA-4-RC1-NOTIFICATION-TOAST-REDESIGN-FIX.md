# RusticQ Alpha 4 RC1 — Notification Toast Redesign Fix

This is a design/interaction patch, not a new release or RC. It preserves the existing Gruvbox and Aether color tokens.

## Changed

- Rebuilt the toast using a single, border-only outer panel, removing the vertical accent stripe and decorative footer badge entirely.
- Aligned application icon/name, notification category, timestamp, close affordance, title, and body consistently.
- Use the actual application icon (`Quickshell.iconPath`) when provided; otherwise use an existing Material Symbols glyph from `assets/google.ttf`.
- Screenshot notifications with an image use a compact preview thumbnail at the right side. No image means no placeholder thumbnail or wasted width.
- Width adapts to thumbnail presence; height comes from the content's natural `implicitHeight`, with a minimum to avoid clipping or stacked text.
- The sender's actual desktop notification actions (maximum two visible) appear in the toast and history; activating a button calls `NotificationAction.invoke()` with the original action index. No made-up screenshot paths, shell commands, or fake Open File/Folder buttons.
- Text is displayed as plain text, and title/body line count is bounded so exceptionally long notifications cannot take over the screen.
- `NotificationServer.actionsSupported` enabled so senders can offer native actions.

## Files touched

- `modules/main/NotificationToasts.qml`
- `modules/bar/BarNotifications.qml`
- `services/NotificationCenter.qml`

## Smoke test on Hyprland / Quickshell 0.3.1

1. `qs -p .` from your RusticQ config directory.
2. `notify-send -a 'RusticQ Test' 'Notification style' 'No left stripe and no overlapping text.'`
3. Trigger an Omarchy screenshot action. If the sender provides a thumbnail it appears on the right. If it provides native actions, buttons appear; without them nothing extra is invented.
4. Test a notification with an action, e.g. `notify-send --action=default=Open 'Action demo' 'Click the button'` (syntax/support depend on installed `notify-send`).
5. Open Quick Control → Notifications: confirm list items remain usable even when action buttons are present.
6. Confirm the toast closes after a short delay or via X and that the history is preserved until cleared.

## Scope / verification

Static QML structure, glyph checks, and notification interaction source regression checks are run offline. Live layout rendering, image loading, D-Bus action invocation, and compositor behavior **must still be checked in Hyprland**. Other active notification servers still prevent RusticQ from owning `org.freedesktop.Notifications`.
