# RusticQ Beta 3 — Compositor Studio (Hyprland / Niri)

A small, **schema-limited graphical configuration editor** in Settings → Compositor.
Conceptually informed by [HyprMod](https://github.com/BlueManCZ/hyprmod), but NOT a
fork, plugin, or duplicate compositor daemon. It reuses RusticQ Settings and
RusticQ's existing keybinding/monitor tools. It does not install HyprMod.

## Supported sections (verified against documented syntax)

| Setting | Hyprland Omarchy Quattro Lua | Niri KDL |
| --- | --- | --- |
| Detect active compositor | Session env/socket | Session env/socket |
| User session autostart | `hl.on("hyprland.start", …)` / `hl.exec_cmd` in `~/.config/hypr/autostart.lua` | `spawn-sh-at-startup` in `~/.config/niri/config.kdl` |
| Gaps | `hl.config({ general = { gaps_in, gaps_out } })` in `looknfeel.lua` | `layout { gaps N }` in `config.kdl` |
| Corner rounding | `hl.config({ decoration = { rounding } })` | **Read-only** (different schema) |
| Keyboard layout / input | `hl.config({ input = { … } })` in `input.lua` | **Read-only** until version-specific validation |
| Monitor output profile | `hl.monitor({ … })` in `monitors.lua` | **Read-only** (use native Niri tools) |
| Keybindings | **Existing** Settings → Shortcuts | No automatic editing |
| Monitor live-test | **Existing** Settings → Displays | Not supported |
| Window/layer rules | Read-only, version-sensitive | Read-only, version-sensitive |

In particular, Omarchy Quattro **does not load** old `.conf` files for its user
configuration. The editor requires the corresponding `require("hypr.⋯")` in
`hyprland.lua`. If the module is not loaded, editing fails safely.

Official technical references:
- HyprMod `BlueManCZ/hyprmod` for the editor architecture and conservative
  isolation, not for copied source code.
- Omarchy Quattro `default/agents/skills/omarchy/hyprland.md`, `config/hypr/hyprland.lua`,
  `default/hypr/autostart.lua` for runtime Lua commands and entrypoint.
- Niri official Configuration Introduction, Include and Miscellaneous for KDL
  format, startup, and config validation.

## Safe lifecycle

1. **Detect** active compositor. Ambiguous or unsupported sessions become read-only.
2. **Preview changes** — displays unified diff; no disk modifications.
3. **Apply verified preview** — the preview fingerprint includes both the
   current source and every requested setting. If another program edits the file
   between these steps, Apply is rejected.
4. **Snapshot** the exact user file before an atomic write. Snapshots and SHA-256
   manifests are stored privately in:
   `~/.local/state/rusticq/compositor-config/history/snapshot-*/`.
5. **Validate** compositor config. Hyprland: `hyprctl reload` then
   `hyprctl configerrors`. Niri: `niri validate --config <user-config.kdl>`.
6. **Rollback** on validation failure: restore bytes and verify again. If the
   user later modifies the file, a manual rollback refuses to overwrite those
   newer changes.

**Autostart changes execute next session**, not during live preview/apply.
The editor does **not** execute arbitrary commands as root, does **not** edit
`/usr/share/omarchy`, and does not assume a missing validator means success.
Only one managed block per section is touched; unrecognized parts of the file
are left byte-for-byte unchanged.

## CLI usage

```sh
cd ~/dev/quickshell
python3 scripts/rusticq-compositor-config.py status
python3 scripts/rusticq-compositor-config.py history
python3 scripts/rusticq-compositor-config.py preview --section autostart --values '{"commands":["waybar"]}'
```

The preview response returns a `token`. To apply that exact preview:

```sh
python3 scripts/rusticq-compositor-config.py apply --section autostart \
  --values '{"commands":["waybar"]}' --token '<token-from-preview>'
```

And to restore a snapshot if it is still the most recent content in the file:

```sh
python3 scripts/rusticq-compositor-config.py rollback --snapshot snapshot-<id>
```

## Limitations and known risks

- The current build environment cannot launch a real Hyprland/Niri compositor,
  so runtime config syntax and exact monitor response must be verified on the
  user's device. The 29 mocked tests verify transaction logic, **not** live
  hardware/API behaviour.
- For monitor changes, use Settings → Displays' timed live confirmation first.
  On a multi-monitor system avoid editing output profiles remotely without a
  TTY recovery path. Raw Hyprland profiles may require manual recovery.
- Existing Omarchy autostarts remain visible in their source but are not
  auto-imported into the RusticQ-managed list. Avoid starting the same daemon
  twice.
- In Niri, use `spawn-sh-at-startup` only on a compatible version (>=25.08).
  Niri's built-in validator is mandatory. The KDL parser is not reimplemented.
- The GUI does not manage Niri input, Niri output positions, or compositor
  window rules until a tested version-aware schema is available. These are
  *deliberate safety boundaries*, not hidden working buttons.
- UI support is read/write for the **managed blocks**. It does not transform
  every possible arbitrary user-authored Lua/KDL setting into GUI controls.

## Verification checklist (29 independent checks)

The regression test `tools/test_compositor_studio_safety.py` contains 29 cases
covering Hyprland/Niri detection, unknown-session gating, schema gating,
validation of commands/layout/monitors, preview immutability, safe escaping,
managed-block isolation, optimistic concurrency, symlinks, Lua require checks,
failed validation recovery, stale rollback protection, Niri KDL validation,
missing validator handling, and preservation of unrelated user config lines.

Run `python3 tools/test_compositor_studio_safety.py` and
`python3 tools/verify-static.py` before deployment.
