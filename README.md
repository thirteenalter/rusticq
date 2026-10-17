# RusticQ · Alpha 4 RC2

A modular desktop shell for **Quickshell 0.3.1**, Hyprland, Arch Linux, and Wayland. Supports the original **Gruvbox** palette or **Follow Aether** applied colors, Poppins, and Google Material Symbols.

## Install / test

Back up your active configuration. Extract this complete archive and launch from the directory containing `shell.qml`:

```bash
qs -p .
```

Test with a separate directory before replacing your existing shell. Quickshell 0.3.1 and a working Hyprland session are required. System features optionally use NetworkManager, BlueZ, UPower, PipeWire, and other existing desktop services.

## Alpha 4 RC2 corrective fix — icon placement & package management

- Every primary bar icon supports Left / Center / Right placement in Settings → Bar; vertical positions map to Top / Middle / Bottom.
- New package management actions in Settings → Installed Apps require explicit confirmation, with an interactive terminal and risk warnings.
- Dynamic audio levels, new `e322` Task View icon and `f371` AI launcher.
- Full changes and limitations: `changelog/ALPHA-4-RC2-BAR-PACKAGE-FIX.md`.

## Alpha 4 RC1 corrective fix — Omarchy update + dock windows

RusticQ detects Omarchy's guarded update flow and launches `omarchy update` interactively in a terminal after user confirmation rather than calling `pacman -Syu` directly. The Dock → Show running apps switch now observes Hyprland's live toplevel model. See [`changelog/ALPHA-4-RC-1-OMARCHY-DOCK-FIX.md`](changelog/ALPHA-4-RC-1-OMARCHY-DOCK-FIX.md). No version bump.

## Alpha 4 RC1 correction — Settings window & dock alignment

Settings starts as a smaller floating top-level window (940 × 660 px), without an internal outer rounded border or header close button. Hyprland controls the outside corners. A targeted, best-effort Hyprland Lua dispatcher helper floats and centers only the RusticQ Settings window without editing your compositor configuration. Dock width follows its actual visible row contents, keeping both margins balanced. See [`changelog/ALPHA-4-RC-1-FLOATING-SETTINGS-DOCK-ALIGNMENT-FIX.md`](changelog/ALPHA-4-RC-1-FLOATING-SETTINGS-DOCK-ALIGNMENT-FIX.md). No version bump.

## Alpha 4 RC1 additions

- Settings now includes OS information, Hardware, Installed Apps, Storage, and Arch Updater as independently scrollable sidebar destinations.
- OS and hardware diagnostics are read-only. Installed Apps includes graphical desktop entries and the searchable pacman inventory.
- Arch Updater supports safe `checkupdates` checks, shows pending package versions, and displays persistent live pacman output. Upgrades require separate manual confirmation and PolicyKit authorization; no upgrade runs automatically.
- The sidebar scrolls when categories exceed the screen height, and Settings search covers new pages.
- See **[`changelog/ALPHA-4-RC-1.md`](changelog/ALPHA-4-RC-1.md)** for full details and safety notes.

## Alpha 4 changes

- Moved prior release notes and hotfix summaries into **[`changelog/`](changelog/)**. Root `README.md` now describes the current project instead of concatenating obsolete version notes.
- Replaced the fixed **Wi-Fi/Battery** spacer with adjustable per-icon spacing; default distances are compact again. Use **Settings → Bar → Icon spacing** to select Left/Right, edit the baseline group gap and the Before/After margins of any icon. Values persist separately for each bar mode.
- Added **Dock → Show running apps** (off by default): list of real graphical windows advertised through Hyprland, icon via the desktop icon theme, click to activate; horizontal scrolling when the row outgrows the display. Not a list of background processes.
- App Launcher is now a **single card**, with the only border on its outer surface.
- **Quick Control drag arrangement**: click the handle/reorder icon in the header, drag a section by its grip and release to move it. Order is saved as `quickControlOrder` in `user-settings.json`. Reset button restores the original order. Notifications adopts the same section-header design.

## Manual spacing (Alpha 4 correction)

The left and right bar groups now have separate baseline spacing controls, plus individual Before/After spacing for Arch/AI, App Search, Menu, Workspaces, Weather, Clock, Date, Bluetooth, Wi-Fi, Battery, Audio, Task View, Quick Modes, and Quick Control. Spacing is based on layout margins rather than absolute positions; it adapts when icons are hidden. The Left/Right vertical bar uses the same controls as top/bottom margins. **Reset icon** clears the selected icon overrides; **Reset this side** clears the active side for the current layout mode. No previous `user-settings.json` values are overwritten.

## Quick Control default order

Wi-Fi → Bluetooth → Battery → System → Notifications. System remains permanently expanded, independently of its position.

## Settings

Use the Settings sidebar for Appearance, Bar, Modules, Widgets, Dock, Displays, OS Information, Hardware, Installed Apps, Storage, Arch Updater, AI Providers, and About. The new **Show running apps** option is under **Dock**. User preferences are stored in `user-settings.json`; API credentials remain in the Linux keyring.

## Release notes

See **[`changelog/ALPHA-4.md`](changelog/ALPHA-4.md)** and older records in `changelog/`. Source changes do not guarantee that every interaction works on a real Hyprland installation. Verify using `qs -p .` and `qs log -f`.
