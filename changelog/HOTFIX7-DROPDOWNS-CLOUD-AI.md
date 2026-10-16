# Hotfix 7 — Dropdowns, System always visible, Cloud AI

Target: **Arch Linux / Quickshell 0.3.1**. Based on the latest UI-stability sources from Hotfix 6; fixes Hotfix 5 logs supplied by the user. Preserves Gruvbox Dark palette, Poppins, and Material Symbols.

## Confirmed issues and fixes

1. **Bluetooth & Battery headers did not respond to clicks.** The shared `SectionHeader.qml` was an `Item` with only `Layout.preferredHeight: 36`, but Bluetooth and Battery positioned it with `x/y/width`, outside a layout. This means the actual `height` could be zero and its `MouseArea` would never receive clicks. Added `height: 36` and `implicitHeight: 36`. Components now have independent `expanded` properties to prevent cross-card state side effects. Wi-Fi also uses its own expanded state.
2. **System should always show.** `BarSystem.qml` no longer has dropdown state or a chevron. CPU/RAM/root-storage/temperature rows remain visible; the storage metric includes GiB available.
3. **Pill binding loops in logs.** `Pill.qml` used `childrenRect` for its own implicit size while children were positioned relative to their parent; replaced it with explicit implicit sizing based on the visual child's own preferred dimensions. Unlike fixed-size pills, time and status widths can still grow with their content.
4. **AI previously depended on Ollama and exposed awkward layout.** Sidebar uses API calls to OpenAI, Anthropic, or Google Gemini, via `scripts/cloud_ai.py`. Prompt and secret are provided via *stdin*, never command-line arguments. AI history is held in memory only; only the selected provider and model ID are persisted in `user-settings.json`.
5. **Key security.** Key saved per-provider through `secret-tool store` (Secret Service/libsecret), never in the ZIP, JSON, environment setup file, or process argument. You must have an unlocked Secret Service keyring. Settings provides status/save/remove controls.
6. **Portal warning.** `qt.qpa.services ... Could not register app ID` is independent of the QML dropdown issue. If it persists, check for multiple running shells/portal processes; this patch does not claim to fix the host portal.
7. **Repeated Wi-Fi discovery logs.** Multiple `WifiManager` init logs do not by themselves prove three devices; Quickshell reloads or multiple shells can initialize the service repeatedly. Check `pgrep -af quickshell` before assuming it is the device list. This patch does not remove Wi-Fi hardware discovery logs.

## Install on Arch

```bash
sudo pacman -S python libsecret xdg-utils
# Confirm secret-tool is installed
command -v secret-tool
# Confirm the keyring daemon is running/unlocked (GNOME Keyring / KWallet Secret Service)
# Unzip to a NEW folder, then run from the parent folder:
qs -p ./quickshell
```

Open **Full Settings → AI Providers**, select OpenAI, Anthropic or Gemini, configure a model ID, paste your *provider API key*, and choose **Save key**. **Check status** should show that it is configured. Then click the Arch icon at the bar's left and send a message. A test network connection is possible only when the computer can reach the provider's API.

Default model examples (availability/billing depend on the provider and your account):
- OpenAI: `gpt-4.1-mini`
- Anthropic: `claude-haiku-4-5-20251001`
- Gemini: `gemini-2.5-flash`

Change model IDs in Settings whenever your provider adds/removes models. A normal subscription/login to ChatGPT, Claude or Gemini **is not the same as an API key** and may have separate billing. The **Open provider website** action launches your browser to log in there; it does not grant this shell access to website sessions. No hidden token extraction / browser-cookie reuse is attempted.

Endpoints: OpenAI `/v1/responses`, Anthropic `/v1/messages`, Gemini `models/{model}:generateContent`. Cloud AI messages are sent to the selected provider and may be processed or retained under that provider's terms; this is *not* a local/private inference backend.

## Validate

```bash
python3 quickshell/tools/verify-static.py
python3 quickshell/tools/test_cloud_ai.py
qs -p ./quickshell
qs log -f
```

Smoke test in Hyprland:
1. Open Quick Control; click **Bluetooth** title or chevron twice: list expands and closes. Repeat Battery; change Balanced/Power Saver and check current profile. Requires BlueZ + system power-profile service.
2. Scroll to **System**: no chevron, always four metrics. Storage shows root filesystem used/total and free in GiB.
3. Watch bar clock and icons; `Pill.qml` implicit-size warnings should disappear.
4. Open **Settings → AI Providers**: verify provider selection, key saving, status, and deletion. Select model ID for your account. No key should appear in `user-settings.json` or `ps aux` command lines.
5. In left **Arch AI** sidebar, send a message: a reply should appear or an actionable error (keyring, network, quota, model) should be shown. Ensure the composer remains at the bottom.

**Test limitations:** The build environment does not have a running Quickshell 0.3.1/Hyprland/BlueZ/Secret Service session, so a full graphical runtime test is pending. QML structural and Python helper contract tests were performed offline.

## References

- https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process/
- https://quickshell.org/docs/v0.3.1/types/Quickshell/Quickshell/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Bluetooth/BluetoothAdapter/
- https://developers.openai.com/api/reference/overview
- https://platform.claude.com/docs/en/api/messages/create
- https://ai.google.dev/api/generate-content
