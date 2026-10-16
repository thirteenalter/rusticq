# RusticQ Alpha 3 — bar layout and edge positioning

Target: **Quickshell 0.3.1**, Arch Linux / Hyprland. Based on `rustiq-alpha-2`.

## What changed

- **Top / Bottom / Left / Right** in **Full Settings → Bar & modules → Bar position**, saved to `user-settings.json` as `barPosition` (default `top`). It applies to all monitors that render RusticQ bars.
- Top/Bottom keep the existing five bar styles and modules, but use consistent padding, adjusted heights (42–46px), and 8–12px spacing. The Professional title is centered relative to the screen, not relative to uneven content widths.
- Left/Right use a 64px *vertical* rail with launcher, six workspace buttons, weather, time, date, Bluetooth, Wi-Fi, battery, audio, and Quick Control. The center rail section scrolls when the display is short. Rail indicators open the same single-feature popups. Settings remain available from Full Settings.
- Mini popups are anchored **below** Top, **above** Bottom, **to the right** of Left, and **to the left** of Right, using `PopupAnchor.edges`/`gravity`. They are clamped along their main screen axis.
- Gruvbox/Aether tokens, five bar styles, cloud AI, and existing mini widgets remain available.

## Usage

```bash
qs -p ./quickshell
```

Go to **Full Settings → Bar & modules** to select an edge. Your previous mode remains saved when you switch to a side bar; return to Top or Bottom to use it again.

## Testing checklist (must be run on your Hyprland session)

1. Change Top → Bottom → Left → Right → Top. Watch for QML errors and verify that the shell window actually moves to the selected edge.
2. On each edge, click Wi-Fi/Bluetooth/Battery/Audio plus the clock, date and weather. Check direction and on-screen positioning.
3. On Left/Right, switch workspaces and verify the active workspace highlight. Scroll the rail on a small monitor.
4. Switch through all five layout modes while Top/Bottom is active. Test bar width in both narrow and wide resolutions.
5. Open and close Quick Control, AI sidebar, and Full Settings; then restart `qs` and verify saved `barPosition`.
6. Check colors both under Independent Gruvbox and Follow Aether.

## Limitations / dependencies

- **Not runtime-tested:** the archive was checked statically without a live Quickshell 0.3.1 / Hyprland compositor session. Edge transitions and popup gravity need real-world validation.
- The fixed Quick Control and AI sidebars remain anchored right/left respectively, even if the bar is moved. Their side is independent from bar position. A fully position-aware sidebar is a separate enhancement.
- Side rails intentionally show icon-only indicators with compact time/date. The full text remains in mini popups.
- If you have an old user-settings.json with no `barPosition`, the default is Top. If you replace the old settings file, back it up first to retain custom provider/model/theme choices. API keys stored in Secret Service are not included in this ZIP.

## Verification performed

Run `python tools/verify-static.py` and `python tools/test_rustiq_alpha3.py`; both check source structure, API wiring, and fonts, **not** live QML geometry. Core older regression scripts are also included.
