# RusticQ Beta 1 — Evidence-based 50-feature Audit + Phase A Implementation

**Audit input:** User-provided `quickshell.zip` (Beta 1 source, Oct 2026). This report is not an audit of the older RC4 snapshot. Run-time Quickshell 0.3.1 and a live Hyprland session are unavailable in this build environment. All statuses therefore remain conservative.

## A. Source architecture summary

- **Shell entry:** `shell.qml`, per-monitor `Bar` and `DesktopWidgets`, LazyLoader launcher/monitor/settings, IPC target `rusticq` and Hyprland focused monitor mapping.
- **State:** singleton `config/Store.qml` (ephemeral UI/window state), `config/SettingsStore.qml` (persistent JSON), QML singleton `services/*.qml` and user-private AI credential storage.
- **UI:** `modules/main`, `modules/bar`, `modules/settings/pages`, `modules/quickcontrol`, `modules/process`, `modules/ai`, shared `components`.
- **System scripts:** `scripts/rustiq-desktop-integration.py` for reversible Omarchy Lua shortcuts/startup, `scripts/rustiq-display.py` for live monitor changes, and specialized package/audio/network/media helpers. `scripts/install.sh` installs to a user-local source path without replacing Omarchy by default.
- **Dependencies:** Hyprland, Quickshell 0.3.1 development target, Python and optional PipeWire/BlueZ/NetworkManager/Wayland tools. See `config/dependencies.json`.

## B. Feature matrix

**27 PARTIAL · 23 MISSING · zero fully runtime-verified IMPLEMENTED.** This reflects **feature completeness** as defined by the master prompt, not whether RusticQ can already run. Rows contain source evidence, limitations, conflicts, dependencies and P0/P1/P2 priority.

See [`BETA1-50-FEATURE-MATRIX.csv`](BETA1-50-FEATURE-MATRIX.csv) for all 50 features.

Features expanded in this safe batch:

| ID | Status | Concrete implementation | Remaining scope |
|---|---|---|---|
| #4 | PARTIAL | Optional systemd user unit template, restart-on-failure with StartLimitBurst, explicit unit installation only | Live startup ownership/Omarchy conflict check, journal-based recovery diagnostics |
| #9 | PARTIAL | CLI and Settings Doctor with dependency/service, portal, notifications, live Hyprland and JSON checks | Deep portal/D-Bus/Qt API verification |
| #10 | PARTIAL | 0600 snapshots, atomic JSON restore, locked CLI, Settings snapshot action | Auto pre-migration snapshots, schema-specific recovery |
| #16 | PARTIAL | Safe mathematical expression evaluator integrated into existing launcher; results copy on request | Unit conversion, broader scientific interface |
| #48 | PARTIAL | `rusticq` now dispatches status/doctor/config/ipc/watchdog subcommands, preserving bare GUI invocation | Theme, validated reload, full compositor abstraction |

## C. Conflict and compatibility

1. **Lock (#1), idle (#2), auth (#3, #6):** do not implement an ad-hoc QML password/PAM agent. Integrate installed hyprlock/hypridle/polkit and avoid duplicate Omarchy-managed processes.
2. **Crash supervision (#4):** additional systemd unit **not activated** by setup. Enabling alongside Omarchy autostart would launch duplicate shells. The user must resolve ownership manually first.
3. **Config (#10) and hot reload (#47):** Config Guard restores JSON and retains the overwritten copy. Runtime reload is intentionally not invoked automatically; restart only after manual validation.
4. **Launcher (#11, #12, #16):** existing DesktopEntries and AppUsage remain the single source for app ranking. Calculator activates only for queries beginning `=` and cannot execute arbitrary code.
5. **Portals, notifications, audio, wallpapers (#21–24, #31–36):** use existing shared QML services. Doctor does not start new polling or duplicate bus owners.
6. **Remote/system features (#14, #17–18, #41–44):** keep optional, opt-in, no silent cloud transmission or clipboard indexing of secrets.
7. **Omarchy (#7, #8, #50):** live monitor changes are session scoped; do not overwrite default distro files or enable additional service by installing an archive.

## D. Roadmap

**P0 stability:** Test new Doctor/Guard in a real Wayland session; inventory existing hyprlock, idle and polkit. Resolve restart ownership before testing optional watchdog. Validate session integration and monitor hotplug restore.

**P1 usability:** Finish universal search, keyboard focus/accessibility, notifications and PipeWire stream mixer; implement validated theme/CLI reload and safe configuration schema migrations.

**P2 optional:** Clipboard encryption, OCR, wallpaper search, dynamic island, plugins, local AI and multi-compositor adapters only after explicit permission/capability interfaces are designed.

## E. Implementation details

- **Added:** `scripts/rusticq-doctor.py`, `scripts/rusticq-config-guard.py`, `scripts/rusticq-cli.py`, `scripts/rusticq-watchdog.py`, `scripts/rusticq-calc.py`.
- **Modified:** `modules/settings/pages/SettingsIntegrationPage.qml` (Doctor + snapshot card), `modules/main/MiniLauncher.qml` (`=` calculator), `scripts/install.sh` (CLI routing while preserving GUI startup), `README.md` and this report.
- **Added tests:** `tools/test_phase1_doctor_guard.py`, `tools/test_beta1_feature_batch.py`.
- **No new compulsory dependencies.** The calculator copy action requires the already optional `wl-clipboard` package. Doctor is read-only. Config snapshots are private. The watchdog unit is neither enabled nor started.

## F. Performance

No startup CPU, RSS/PSS, animation latency or compositor benchmark was measured, because the container has no live Wayland/Quickshell session. New Doctor, Config Guard, CLI and Calculator are short-lived subprocesses. The calculator is debounced and only invoked on an explicit `=` query; systemd supervision is inert unless separately enabled. **Do not infer lower CPU from architecture alone.**

## G. Remaining backlog

The full 50-feature matrix explicitly records every missing or partial checklist item. In particular: secure locking and FIDO2 (#1/#6), clipboard privacy (#14), OCR/reverse image search (#17/#18), plugin SDK (#46), Niri/Sway backend (#8), hot reload (#47), and distribution packaging (#50) are **not completed** in this batch. Avoid exposing unfinished features as functional Settings buttons.

## H. Verification and limitations

Offline tests: Config Guard/Doctor, calculator injection prevention, optional unit safety, CLI and Settings integration, Beta 1 startup/static checks. Runtime QML loading, actual Hyprland monitor/session/lock behavior, systemd service enabling, Omarchy integration and performance have not been tested. **Apply the patch to the same Beta 1 upload**, and test using `qs -p .` before any permanent integration.

### Manual commands

```bash
python3 scripts/rusticq-cli.py status
python3 scripts/rusticq-cli.py doctor
python3 scripts/rusticq-cli.py config backup settings
python3 scripts/rusticq-cli.py config list settings
python3 scripts/rusticq-cli.py config restore settings SNAPSHOT_ID --confirm RESTORE
python3 scripts/rusticq-cli.py watchdog status
# To install an inert, disabled systemd unit only:
python3 scripts/rusticq-cli.py watchdog install --confirm 'INSTALL WATCHDOG'
```

For an installed RustiсQ (`scripts/install.sh`), replace `python3 scripts/rusticq-cli.py` with `~/.local/bin/rusticq`. Running the launcher with **no arguments** still opens RusticQ as before.
