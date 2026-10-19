# RusticQ Beta 1 — Major Feature Expansion Phase 3

> **Source baseline:** `rusticq-beta1-phase2-major-full.zip`, not Alpha/RC4. This is an additive, testable batch rather than an unsafe claim that all 50 matrix entries are production-ready.

## A. Source architecture and compatibility

- Existing `shell.qml`, `Store`, `SettingsStore`, Quickshell `DesktopEntries`, PipeWire service, notification daemon, power/Omarchy handling, and per-layout bar profiles remain authoritative.
- New launcher providers call existing `MiniLauncher.qml` → `scripts/rusticq-launcher-tools.py`. On-demand helpers `rusticq-desktop-search.py` and `rusticq-notes.py` have no daemon or privilege escalation.
- New `SettingsNotesPage.qml` reuses the Settings window's established page navigation and `SettingsSection` design.
- Per-app audio streams are obtained from Quickshell's existing `Pipewire.nodes` and only tracked when Advanced Audio is open. No pactl/wpctl polling loop.
- Notification grouping is a derived display of **one existing NotificationCenter history**, never a second notification store or daemon.
- Desktop profile presets modify only RusticQ user preferences and preserve a prior state for restoration; no uncontrolled Omarchy/Hyprland/service policy changes.

## B. Audit matrix

See `BETA1-50-FEATURE-MATRIX.csv` for 50 rows, code evidence, conflict risk and remaining prerequisites. Status `PARTIAL` means only part of the requested feature is implemented. Read-only offline tests cannot prove Wayland runtime behavior.

## C. New/extended functionality

| Matrix | Implemented in this batch | Remaining gaps |
| --- | --- | --- |
| #9 System Doctor | Local provider capability diagnostics and Notes/Kanban backend presence. | Privileged component status, some portal and D-Bus checks under live user session. |
| #11 Universal Search | `:files`, `:folders`, `:windows`, `:workspaces` in existing launcher; bounded personal files scan, Hyprland live focus. | Global indexer, complete independent-provider SDK; compositor-specific focus needs device validation. |
| #31 Grouped Notifications | Toggle group-by-app; expand/collapse app groups using current notification history and action references. | Threaded messages/inline reply, persistence and DND policy. |
| #35 Per-App Audio Mixer | Native PipeWire stream volume/mute inside existing Audio Advanced UI. | Per-stream output routing, live multi-app test and further accessibility controls. |
| #45 Desktop Notes & Kanban | Notes board in Settings, add/move/delete, private atomic local JSON, `:notes` launcher, `rusticq notes` CLI. | True desktop sticky-note widget, drag/drop board, attachments and optional sync. |
| #48 CLI | `rusticq notes list/add/move/toggle/delete` extends existing CLI. | Theme and hot reload commands. |
| #49 Desktop Profiles | Gaming/Coding/Battery/Presentation profile presets in Modules with Restore previous option. | Power service orchestration, user-defined presets, cross-session power policies. |

## D. Security and conflict resolution

- **No replacement compositor or external authorization agent.** Do not run two lock/idle/polkit daemons. Never fake PAM, FIDO2, or encrypted-clipboard availability.
- **Local file search privacy:** explicit prefix only; standard user directories; hidden names and symlinks excluded; walk bounded by entry count/depth. `xdg-open` executes only on a selected verified file/folder.
- **Window switching:** read current Hyprland clients/workspaces, accept only validated live address or positive workspace ID; no arbitrary IPC execution string is passed through.
- **Notes privacy:** no network calls; maximum 250 notes, 260 characters per note; file mode 0600 under private state directory, synchronized atomic writes, schema validation and lock.
- **Audio:** use Quickshell PipeWire node tracking, not an external mixer daemon; sampling only when Advanced opened.
- **Notifications:** groups are presentation-only: dismiss and app actions continue to reference original notifications.
- **Profiles:** only RusticQ UI settings are changed; Omarchy DND, logind, system power manager and lock policies stay authoritative.

## E. Verification & performance

`python3 -m unittest discover -s tools -p 'test_beta3_features.py' -v` tests privacy, notes lifecycle, source integration, window selectors and profile QML wiring. Existing Phase 1/2 regression suites and `tools/verify-static.py` are also executed before packaging.

No benchmark of idle memory, real audio streams, notification ownership or two-monitor Hyprland switching was possible in this container. **These must be validated in your live session.** Providers do not start in the background and have a bounded file scan. Memory/performance improvement is not claimed without measurements.

## F. Remaining backlog

All other matrix entries remain `PARTIAL` or `MISSING` as described in CSV. High-risk missing modules (custom session lock/PAM, Polkit agent, FIDO2, encrypted clipboard history, multi-compositor adapter, secure calendar sync, sandboxed plugins, replay buffer and automation policies) must not be represented by fake switches or UI-only stubs.

## G. Install

- Full ZIP root: `quickshell/`, intended to replace the entire source folder after backup.
- Patch ZIP root: `quickshell/`, to be **overlaid on Beta 1 Phase 2** source with `unzip -o PATCH.zip -d ~/dev`. It contains only new/modified files. It has no installer.
- Neither ZIP includes personal settings/keys, performs automatic package management, or changes the active Hyprland session by extraction.

## H. Live test checklist

1. Start `qs -p .` and check QML startup errors.
2. Launcher test `:files report`, `:folders projects`, `:windows firefox`, `:workspaces 2`, `:notes +Buy milk` and `:notes milk`.
3. Open Settings → Notes & Kanban; advance/complete and delete a note. Check persistence after restart.
4. Open Audio → Advanced while another app plays audio; test per-app volume/mute while monitoring output and mic peak.
5. Expand Notifications → toggle grouping → expand/collapse a grouped app; verify dismiss/actions still work.
6. Settings → Modules → Desktop profiles → Gaming → Restore previous. Verify other bar mode icon profiles stay intact.
7. Test launcher keyboard focus, Settings scroll, monitor rollback and Omarchy revert workflow from earlier phases.
