# RusticQ Beta 3 (`beta-3`)

Date: 2026-10-19

## Release versioning

- Promote local source release tag to `beta-3`, display name **Beta 3**.
- Add `VERSION` for CLI/updater and `config/ReleaseInfo.qml` singleton for UI.
- Settings header, sidebar footer and About now use shared QML metadata instead
  of hardcoded Beta 1 strings.
- Update checker compares GitHub release tags with the actual `VERSION` in
  DEV or permanent source instead of stale update-state metadata. A release
  older than the selected target is identified as a downgrade and is not
  automatically described as a newer update.
- Keep published historical Beta 1 documentation; rename no previous tags.
- No settings migration, new daemon, altered dependencies or changes to the
  installed Omarchy/Hyprland configuration are involved in the version bump.

**This is source versioning, not publication of a GitHub Release.**
The `beta-3` GitHub tag/release must be created and uploaded separately.
Use `python3 tools/build-release.py --out /path --label rusticq-beta-3`
to produce the full/patch source archives and checksums.

## Verification

- Local metadata reports `beta-3` through the CLI and Settings.
- DEV/Permanent local `VERSION` files take precedence over updater history.
- A GitHub `beta-1` result is recognized as older than local `beta-3`.
- No original Omarchy configuration or user settings were touched.
- The full/patch ZIPs can be installed as overlays under `quickshell/`.
