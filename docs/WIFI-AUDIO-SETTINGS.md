# Full Settings, hidden Wi-Fi and application audio

Open **Edit → Full settings** or **Tools → Full settings** to reach the settings
overview. **All / UI / System** switches between all pages, RusticQ interface
customization, and system/device controls. Bar remains a dedicated UI page.
Search works across both groups; the launcher also accepts `:settings wifi`,
`:settings bluetooth`, and `:settings audio`.

## Fullscreen and floating device settings

The normal Wi-Fi and Audio **Advanced** buttons still expand their existing
in-panel settings. A separate Material fullscreen icon (`\ue5d0`) in the Wi-Fi,
audio, Bluetooth and battery headers opens the selected device's settings in a
fullscreen window on that monitor. System Settings pages have the same icon.
The anchored popup closes before the fullscreen window opens.

Wi-Fi has dedicated Networks, Add Wi-Fi, Details, DNS and QR sharing buttons.
Audio has Applications, Speakers and Microphone buttons. Buttons for sections
already on screen keep those controls visible; longer pages scroll to the
requested section. Back returns to the main section, then closes the window.
The exit-fullscreen icon changes it to a movable, resizable floating window;
the fullscreen icon restores fullscreen. This window remains separate from the
full Settings overview and shares the existing device services.

System settings includes Wi-Fi, Bluetooth, audio, battery/power, displays,
compositor settings, OS/hardware information, installed applications, storage,
updates and shortcuts. These pages reuse the existing desktop services.

## Hidden Wi-Fi

In the Wi-Fi popup, Quick Control Wi-Fi card or System → Wi-Fi, select
**Advanced Wi-Fi → Add hidden Wi-Fi**. Enter the exact SSID, select
WPA/WPA2 Personal, WPA3 Personal or Open, and press Connect. SSIDs retain
leading/trailing spaces and must fit the Wi-Fi limit of 32 UTF-8 bytes.
Enterprise authentication remains outside this form's scope.

Advanced is a separate page containing network details, traffic rates, QR
sharing and DNS controls. **Back to Wi-Fi** restores the scanned network list.
The form's Back button returns to the advanced details. Closing or leaving the
form clears its input; a connection already in progress continues through the
shared Wi-Fi service.

The helper runs only on Connect. Credentials travel over stdin and an anonymous
memory descriptor; they never enter process arguments, logs or user-settings.json.
NetworkManager saves a successful connection. Failed attempts remove only their
new temporary connection UUID. Existing Wi-Fi scanning/connections remain native.

## Application audio and live meters

The audio popup's Advanced section, Quick Control's Advanced Audio and
System → Audio share the same application mixer. Each playback stream displays
its application/media name, volume, mute button and a separate live level meter.
Capture streams and internal peak-monitor streams are excluded.

Quickshell 0.3.1 marks `AudioOutStream` with the Sink flag. Its native peak
monitor also fails when an application reports Unknown channel positions
while capture uses FL/FR. The mixer uses native monitoring for named channels
and an in-memory `pw-cat` fallback for unnamed channels. The fallback needs
`pipewire-audio` on Arch; unavailable capture shows a clear status.
Monitoring stops when the mixer is hidden. Audio samples are not saved.

## Verification

- `python3 tools/verify-static.py`
- `python3 tools/check-bar-modes.py`
- `python3 -B tools/test_wifi_hidden.py`
- `python3 -B tools/test_wifi_audio_ui.py`

The UI suite uses isolated settings and fake devices. Separate offscreen testing
against the live PipeWire session detected Spotify/Brave, observed changing Spotify
peaks, and produced no PipeWire errors after the channel fallback was applied.
Connecting to a real hidden router, Bluetooth pairing and monitor hotplug still
need device testing.
