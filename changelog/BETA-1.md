# RusticQ Beta 1 — UI/UX and installer milestone

Based on Alpha 4 RC5 Setup Edition; no additional runtime packages automatically forced for optional tools.

- Launcher: keyboard up/down selection, Enter launch; pointer hover selects the same row.
- Displays: simpler single-monitor editor, aligned ComboBox for resolution & Hz, better scale/position controls, preview/apply/validation, clearer errors; no false-positive legacy keyword fallback on Lua Omarchy.
- Installed apps: safe pacman desktop-file owner matching and separate confirmation window. Exact package name confirmation before uninstall. Unsupported non-pacman apps are explained rather than removed.
- Bar / Modules: remove redundant Icon preferences section from Bar, keep per-layout profiles and management in Modules.
- Settings: visible scrollbars; 1100×760 px retained.
- Audio: tighter popup, dynamic PipeWire output/microphone peak meters, manual short gentle speaker test.
- Installer: remote GitHub `curl | bash` bootstrapping once scripts/install.sh is pushed to main. User-local only; permanent Omarchy integration remains opt-in.

Test limitations: Real Hyprland dual-monitor rearrangement, live microphone signal and package transactions require hardware/session testing. A changed main branch is not a reproducible release; use checksum-pinned ZIP bootstrap when distributing stable releases.
