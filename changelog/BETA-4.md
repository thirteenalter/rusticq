# RusticQ Beta 4 (`beta-4`)

Date: 2026-11-13

## Release information and About

- `VERSION` selects the active JSON manifest in `config/releases/`.
- Settings and the CLI read the same validated manifest for the version name,
  tag, compatibility requirement, date and release highlights.
- About includes a version selector for documented Alpha and Beta releases,
  release highlights and links to their original local release notes.
- Historical manifests are reconstructed from the referenced repository notes.
  Unknown historical dates remain unspecified. Beta 1 Phase 2 is a feature
  batch, not evidence of a separate Beta 2 release; no Beta 2 is invented.
- Unreadable current metadata produces an explicit error with a retry action.
  Invalid historical entries are skipped with a visible warning.
- Replace stale branding instructions and RUSTIQ Settings labels with current
  RusticQ product information.
- Release archive labels default to the selected manifest; build manifests
  include the complete release metadata alongside archive checksums.
- Exclude local `.aws`, `.codex` and `.agents` directories from release ZIPs.

Quickshell 0.3.1 remains the compatibility baseline. Existing user settings and
installed desktop configuration are not migrated by this source update.
Updating source metadata does not publish a GitHub tag or Release.

## Bar padding and vertical layouts

- Add Settings → Bar → Bar padding editor with four live 0–32 px controls,
  per-layout persistence and an isolated Reset mode action. Inner padding is
  independent of outer margins and per-icon spacing.
- Size horizontal bars and vertical sidebars from their content plus padding.
  Normalize vertical hit areas, give Separated cards inner spacing, and keep
  Professional flush with the screen edge by default.
- Center the middle group when possible, clamp it between its neighbours and
  scroll when the screen is too short. Expand Quick Modes vertically, upward
  in the bottom group so its trigger stays in place when there is room.
- Unload the unused bar orientation so switching edges does not duplicate
  active icon widgets or their service observers.

## Clock countdown timer

- The Time popup keeps its clock and date; an Advanced button opens timer controls
  with hours/minutes/seconds input and 1/5/15/25-minute presets.
- Start, pause, resume and reset work across all clock popups through one shared
  session timer. Closing or unloading a popup does not cancel the countdown.
- Remaining time is recalculated from a deadline, including after suspend or
  delayed frames. Completion produces one notification in RusticQ history and a
  toast when Do Not Disturb is off.
- The popup follows its content height and scrolls on short screens. Back returns
  to the live clock without stopping the timer.
- Timers reset when the shell process restarts; no settings are written.

## Clock audio, alarm and Quick Modes

- Add a shared local alarm with once/daily scheduling, persisted settings,
  Stop and a five-minute snooze. Delayed ticks and resume emit a single alert.
- Timer and alarm sounds loop until stopped by default. Settings → System →
  Clock has a dedicated sound section with Chime/Bell/Digital, local audio files,
  loop/once, preview and independent 0–125% volume, defaulting to 125%.
- Keep audio settings out of the clock popup's Advanced timer view. Missing
  sound files or playback devices leave visual alerts available with an error.
- Silent controls RusticQ DND without requiring a second shell. Keep Awake uses
  a separate Wayland surface plus a logind inhibitor, surviving hidden bars and
  releasing its hold on disable/exit. Performance profile changes get readback.
- Add a saved 2000–6000 K Night Light slider and presets in Modules. Serialize
  helper startup and queued changes so rapid adjustments keep the latest value.

## Calendar notes and quieter layouts

- Select a date and use the compact Add button beside it to create a title,
  Event/Birthday/Work/Holiday category and optional notes. Edit/Delete update the
  entry. Colored dots appear in the popup and desktop calendar.
- Date notes use local calendar dates in existing settings, validated on load
  and saved across shell restarts. Other settings are preserved.
- Refine the calendar agenda into a compact date badge and Add activity row,
  a dedicated activity editor and a saved activity card with Edit/Delete.
- Replace decorative dividers in Weather, audio, networking, menus, AI,
  Settings and lock previews with spacing. Keep outer card borders, input
  boundaries, focus and selection states.
- Device settings always float, with 720×580 preferred size, an 840×620 maximum
  clamped to the monitor and internal scrolling. Remove the fullscreen toggle.

## Recording indicator

- Show a small blinking red dot on every display while the existing RusticQ
  recorder reports an active session. The overlay is independent of the bar,
  reserves no workspace space and passes input through to windows below it.
- Modules settings provide a preview, enabled/blinking switches, four corners,
  dot size and horizontal/vertical insets. New preferences persist with the
  existing settings and retain safe defaults for older configurations.
- Watch recording state changes through FileView in addition to the existing
  status refresh. Stopping no longer hides the indicator optimistically before
  the recorder confirms its state.

## Verification

- Source structure and five bar-mode checks passed.
- Padding checks cover five modes × four positions, per-mode reset/save/reload,
  two screen sizes, short-screen scrolling, long clock labels, expanded Quick
  Modes and popup coordinates. Native Wayland bars also loaded and passed
  geometry checks in every mode/position on both connected monitors.
- Manifest/version parity, historical downgrade comparisons, archive packaging,
  launcher provider, shell updater and Cloud AI offline checks passed.
- Quickshell 0.3.1 offscreen checks opened the history menu, selected every
  documented version and verified error recovery and historical-entry warnings.
- Native countdown checks cover duration input, presets, shared popup state,
  pause/resume/reset, deadline catch-up, completion notifications and DND.
- Clock/mode interaction checks cover alarm scheduling, snooze, persistence,
  System Clock navigation, sound choices/loop/stop, the 125% cap, native DND,
  mocked profile/microphone changes and queued Night Light preferences.
- Targeted live desktop checks verified Night Light apply/restore, effective
  125% PipeWire clock gain and stream removal on Stop, plus the independent
  Wayland surface and logind hold being acquired/released by Keep Awake.
- Calendar checks cover the compact Add/Edit action, category markers, date
  validation, editing/deletion, shared state, scrolling and save/reload.
- Device settings checks cover floating bounds, Wi-Fi/Bluetooth/audio/power
  navigation and delayed section scrolling after the layout settles.
- Recording indicator checks cover status-file updates, blinking, corner/inset
  controls, display-object recreation and saved preferences in offscreen QML
  with a panel model. Recorder lifecycle checks use a fake wf-recorder; real
  video capture and visible Wayland indicator placement remain unverified.
- A full source ZIP was built and checked for archive integrity, version parity
  and exclusion of local credentials and user settings.

Full desktop visual regression, physical multi-monitor hotplug and supported
Gaming hardware were not tested. No running or permanently installed shell was
replaced during verification.
