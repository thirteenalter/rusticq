# RusticQ Beta 1 — Feature Matrix Phase 4: desktop widgets and drag ordering

**Baseline:** the exact Beta 1 Phase 3 full ZIP. This is a source overlay: no services, packages, fonts, personal JSON or installers run when extracting.

## Completed in this phase

- **#45 Desktop Notes & Kanban (extended, still PARTIAL overall):** Notes and Kanban desktop cards, quick add, advance stages, delete, refresh, shared settings/launcher notes database; updates notify other visible UI via `Store.notesChanged`. The backend remains `scripts/rusticq-notes.py`, with atomic private JSON file and no network. A task drag/drop board and attachments are still backlog.
- **#27 Bar Layout Editor (extended, still PARTIAL overall):** drag-and-drop within and across Left/Center/Right bar zones, live order used by BarZone, durable `barIconOrderByMode` per layout, precision arrows and Reset mode. Order and visibility are independent. No direct on-bar editing yet.
- **Local random-image desktop card (user-requested; separate from #24 per-monitor wallpaper profiles):** image from chosen local folder under user's home, manual Next or optional timed rotation; no network, hidden-file scan, symlink following or recursive enumeration. It is a desktop photo card, **not** a system wallpaper manager.

## Safety & compatibility

- Three new widget visibility flags default to **false**. Existing widgets remain positioned as before and stay in the same bottom Wayland layer.
- Default bar order is unchanged for existing users; profiles are migrated non-destructively by treating missing `barIconOrderByMode` as previous stable order. Existing per-mode icon visibility, group spacing and placement are preserved.
- Notes are private and shared with the existing backend, and extra QML loaders are disabled unless a widget is visible.
- Random-image sources are local, bounded to 1,500 entries, limited to recognized image extensions, symlink-free, and must reside under user home. Nothing uploads images.
- Icon drag/drop changes only current RusticQ preferences; no Hyprland or Omarchy config is modified.

## Verification

Run:

```bash
python3 tools/test_beta1_phase4_widgets_bar.py
python3 -m unittest discover -s tools -p 'test_beta*.py'
python3 tools/test_rc4_v5_mode_profiles.py
python3 tools/test_unified_bar_zones.py
python3 tools/verify-static.py
```

Offline tests cover bar ordering, cross-zone moves, reset and mode separation, image selection, symlink escape prevention and source integration. Live Quickshell Wayland drag gestures and image decoding still require the user's hardware session.

## Future backlog

The remaining matrix stays partially implemented/missing as previously reported: authentication, secure clipboard, app calendar sync, multi-compositor adapters, theme synchronization, plugin SDK and other high-risk subsystems are **not** claimed as complete in this phase.

## Suggested live checks

1. Run `qs -p .`; enable Notes, Kanban and Random Image individually in Settings → Widgets.
2. Add a note on desktop, open Settings → Notes & Kanban and check identical content. Advance a Kanban task and verify the desktop card updates.
3. Set photo folder in Settings → Widgets (try `~/Pictures`), then press **Next**. Confirm changing photos and rotation.
4. In Bar → Icon spacing, drag Wi-Fi before Weather, drag it to Left, verify actual bar moves immediately. Switch from Simple to Professional; its order must remain unchanged.
5. Restart Quickshell; widget positions and icon order should persist in `user-settings.json`. Reset the active bar layout; other profiles must be preserved.
