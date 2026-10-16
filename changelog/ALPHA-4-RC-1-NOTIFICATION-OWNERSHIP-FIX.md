# RusticQ Alpha 4 RC1 — Notification ownership & Wi-Fi lifecycle fix

No new release number. This is an operational fix and troubleshooting feature.

## Cause

`Configuration Loaded` means QML loaded. The `NotificationServer` warning is
not a parse error: another D-Bus service owns `org.freedesktop.Notifications`.
Quickshell 0.3.1 cannot subscribe as a second notification server to receive
messages owned by another daemon. It has no `registered` state property.

The Qt xdg-desktop-portal application ID warning is independent. Unless the
portal's functionality fails, it does not prevent notification delivery once
RusticQ owns the notification bus.

## Fix

- Added `scripts/rustiq-notification-doctor.py` (read-only D-Bus owner detection).
- The Quick Control Notifications dropdown now explains which daemon owns the
  bus, shows an actionable hint and allows rechecking.
- `Preview toast` tests the visual UI **without claiming** an app notification
  was delivered. It adds a preview history item. When RusticQ is owner,
  `Send test notification` uses actual D-Bus via `notify-send` (`libnotify`).
- Reduced duplicate Wi-Fi initialization logs by removing scanner side effects
  from the lifecycle of each `WifiManager`. Scan remains user controlled.
- Ignored replayed prior-generation notifications to avoid history duplicates.

## Diagnose your system

```bash
busctl --user status org.freedesktop.Notifications
pgrep -af 'quickshell|mako|dunst|swaync|omarchy-shell'
python3 scripts/rustiq-notification-doctor.py
```

If `busctl` identifies an external daemon, it is expected that RusticQ **does
not** receive system notifications until the other daemon releases the D-Bus
name. Only one server can own it at once. Preview still tests the UI independently.

**Omarchy:** The owner depends on the installed Omarchy version. In older
versions it may be `mako`; in Quattro it can be the built-in
`omarchy.notifications` shell plugin. For Quattro only, to switch the owner to
RusticQ (after verifying the plugin exists):

```bash
omarchy plugin disable omarchy.notifications
omarchy restart shell
```

This disables Omarchy's built-in notification handling. Omarchy features that
rely on its notification plugin may no longer work. Re-enable the plugin if
you want Omarchy handling restored. Do **not** blindly kill another daemon or
set up both to start together. For older Omarchy/Mako or Dunst/SwayNC, inspect
its service and autostart config and disable **only** that owner if you intend
to replace it. No such change is made by this patch.

If `busctl` reports `quickshell` but RusticQ says another owner, check for
multiple running shell instances before launching duplicates.

Once the name belongs to RusticQ, use:

```bash
notify-send -a 'RusticQ smoke test' 'Hello RusticQ' 'A real D-Bus notification'
```

The message should appear in toast and in the Quick Control history if DND is
off. Turning DND on should suppress the toast but retain the history item.

## Testing status

- QML structural and offline Python tests: pass in build environment.
- Actual notification ownership transfer and Hyprland runtime: require a live
  user session, not tested during packaging.
