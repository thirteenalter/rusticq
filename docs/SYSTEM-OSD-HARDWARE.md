# RusticQ Beta 1 — Native System OSD

One transient, non-focusable Wayland OSD is shown on the monitor focused by Hyprland. It uses RusticQ's existing Theme and Fonts and does not register a notification server or grab the keyboard.

## Automatic triggers

- **Speaker volume or speaker mute/unmute:** native Quickshell `PwObjectTracker` + PipeWire audio property change signals. External `wpctl`, media keys and UI controls are reflected if they change the default audio sink.
- **Microphone mute/unmute:** native PipeWire default source property changes.
- **Screen brightness:** a single unprivileged watcher reads `/sys/class/backlight/*/{brightness,max_brightness}` (approx. every 600 ms) and announces changes; does not need `brightnessctl` for observation.
- **Keyboard backlight:** same watcher reads `kbd_backlight`/`keyboard_backlight` LED sysfs values. If neither brightness device is present, watcher exits without leaving an idle process.
- **Touchpad enabled/disabled:** OSD is triggered for RusticQ's own `osd-touchpad-toggle` shortcut after Hyprland confirms the change. It does **not** claim to track arbitrary external mouse disable/enable operations. It never disables a generic mouse or all pointer devices.

The OSD hides after 1.65 seconds, does not alter workspace geometry, and has no independent input/focus grab. Initial PipeWire state is suppressed during a short 1.5 s grace period to avoid an unsolicited startup popup.

## Controls

Settings → Modules → **System OSD** offers an enabled switch and **Preview OSD** button. The preference `osdEnabled` is written to the existing `user-settings.json`, not to another config file.

You can assign these actions in Settings → Shortcuts (no default Omarchy keys are silently overwritten):

| Shortcut action | Meaning |
| --- | --- |
| `osd-volume-up` / `osd-volume-down` | Change output by 5% |
| `osd-volume-mute` | Speaker mute / unmute |
| `osd-microphone-mute` | Microphone mute / unmute |
| `osd-brightness-up` / `osd-brightness-down` | Screen backlight adjustment (5% step) |
| `osd-keyboard-up` / `osd-keyboard-down` | Keyboard backlight adjustment (at least 1 hardware unit) |
| `osd-touchpad-toggle` | Toggle only a detected touchpad; never disables external USB mice |

Custom actions also work with the existing IPC dispatcher:

```bash
qs ipc call rusticq dispatch osd-touchpad-toggle
qs ipc call rusticq dispatch osd-brightness-up
```

Existing Omarchy volume and brightness binds **can remain untouched**: OSD observes their effects. RustiсQ does not make new default keybinds or edit the system's Hyprland defaults. If a key is not bound on your device, assign it yourself in Settings → Shortcuts.

## Dependencies & graceful fallback

- Quickshell 0.3.1 PipeWire service and PipeWire running: required for native audio OSD.
- `/sys/class/backlight/` or `/sys/class/leds/*kbd_backlight`: needed for automatic screen/keyboard brightness observation.
- `brightnessctl`: needed **only when RusticQ itself adjusts brightness**. Your regular Fn keys may still work without it.
- `hyprctl`: needed for `osd-touchpad-toggle`. It reads `hyprctl -j devices`, selects only a named touchpad/trackpad, and uses the `device[name]:enabled` keyword, falling back to Lua `hl.device` on Quattro when required. If the enabled state is not available from Hyprland, the operation refuses to guess.

No root, sudo, daemon registrations, persistent compositor edits, or automatic disabling of the user's pointer device. For unsupported hardware, the popup shows a concise error. No credentials or user data are collected. The watcher runs only while System OSD is enabled and hardware information is available; there is no claim of a measured RAM improvement without an actual session benchmark.

## Manual test sequence (Hyprland)

1. Launch **one** RusticQ instance with `qs -p .`.
2. Settings → Modules → System OSD → Preview OSD.
3. Press the existing volume up/down/mute Fn keys; observe the audio popup and percent.
4. Press brightness Fn keys; verify values change under `/sys/class/backlight` and the OSD appears.
5. If your keyboard has backlight LEDs, change the keyboard light and verify the OSD.
6. Assign `osd-touchpad-toggle`, activate it, check that USB mouse still works, toggle again immediately to restore the touchpad.
7. Disable **Show system OSD** and verify the overlay stays hidden.

If `qs -p .` reports QML warnings, share the complete error and your `hyprctl -j devices` output (remove any private device IDs if necessary). Full end-to-end Wayland testing is unavailable in the release builder.
