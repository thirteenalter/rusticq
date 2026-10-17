# RusticQ Alpha 4 RC3 — AI Workspace, Audio, Appearance Fix

Fix-only RC3 release. Version remains **Alpha 4 RC3**.

## AI workspace
- Reworked the AI panel structure so the message list uses the flexible area and the composer stays a fixed 48px high. This prevents the giant overlapping composer and send button.
- Full-mode uses a **Wayland layer-shell Overlay** with all four monitor edges anchored; it is not a tiled Hyprland application. The sidebar mode retains its narrower size and inset margins.
- Added compact **provider and suggested-model selectors** in the AI workspace; they modify the same `SettingsStore.aiProvider/aiModel` used by Settings.
- Added suggested model selectors in **Settings > AI Providers**, while retaining arbitrary validated model IDs.
- Session-only chat history and Markdown responses are preserved; API keys remain in Linux Secret Service.
- Converted an existing Markdown image sanitization regex into an equivalent `RegExp` construction to keep static syntax scanning reliable.

## Appearance
- Added **Browse file** for wallpapers, launching the available native chooser (`zenity`, `kdialog`, or `yad`) through a safe subprocess (no shell interpolation).
- Added installed font family listing from **fontconfig**, text search, and clickable font selection.
- Added **Add font…** to choose and install TTF/OTF/TTC/WOFF fonts in `~/.local/share/fonts/rusticq/`. No global package or font paths are modified. `fc-cache` refreshes local font cache when available.
- Added persistent `uiCustomFont` setting; existing Poppins, Sans and Monospace options remain available.
- Native picker validates image/font paths under the user's home directory; manual wallpaper apply continues to use the existing backend helper.

## Audio mini-widget
- Removed fixed empty vertical space; the popup height now follows its actual content with safe bounds.
- Advanced now includes PipeWire output and input device lists as in Quick Control, with `preferredDefaultAudioSink` and `preferredDefaultAudioSource` selection.
- Added microphone volume slider, while preserving output slider/mute.

## Verification
- 98 QML files pass the static syntax checks.
- Offline cloud-AI regression tests pass for OpenAI, Claude and Gemini.
- Isolated appearance helper tests include installed-font listing, non-home path rejection, and copy-to-user-font-directory.
- **Not yet runtime-tested** in Quickshell 0.3.1, a live Hyprland session, or against a live PipeWire device switch. Test those before relying on the fix.

## Modified files
- `modules/ai/AiWrapper.qml`
- `modules/main/MiniAudio.qml`
- `modules/main/IndicatorPopup.qml`
- `modules/settings/pages/SettingsAppearancePage.qml`
- `modules/settings/pages/SettingsAIPage.qml`
- `config/SettingsStore.qml`
- `config/Fonts.qml`
- `services/AiChats.qml`
- `scripts/rusticq-appearance.py` (new)
- `tools/test_rc3_ai_audio_appearance_fix.py` (new)
