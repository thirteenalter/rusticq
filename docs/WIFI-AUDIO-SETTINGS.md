# Full Settings, hidden Wi-Fi and application audio

Open **Edit → Full settings** or **Tools → Full settings** to reach the settings
overview. **All / UI / System** switches between all pages, RusticQ interface
customization, and system/device controls. Bar remains a dedicated UI page.
Search works across both groups; the launcher also accepts `:settings wifi`,
`:settings bluetooth`, and `:settings audio`.

## Compact floating device settings

The normal Wi-Fi and Audio **Advanced** buttons still expand their existing
in-panel settings. A separate settings icon (`\ue8b8`) in the Wi-Fi,
audio, Bluetooth and battery headers opens the selected device's settings in a
compact floating window on that monitor. System Settings pages have the same icon.
The anchored popup closes before the device window opens. The preferred size is
720×580, with a maximum of 840×620 clamped to the monitor. Longer content scrolls
inside the window; device settings have no fullscreen toggle.

Wi-Fi has dedicated Networks, Add Wi-Fi, Details, DNS and QR sharing buttons.
Audio has Applications, Speakers and Microphone buttons. Buttons for sections
already on screen keep those controls visible; longer pages scroll to the
requested section. Back returns to the main section, then closes the window.
The window remains movable and resizable within those bounds, separate from the
full Settings overview and shares the existing device services.

System settings includes Wi-Fi, Bluetooth, audio, battery/power, displays,
compositor settings, OS/hardware information, installed applications, storage,
updates and shortcuts. These pages reuse the existing desktop services.

## Search Wi-Fi and Bluetooth by name

The Wi-Fi network list and Bluetooth device list have a search field beside
**Scan** in the popup, Quick Control and Settings. Type any part of a network
or device name; matching ignores case and leading/trailing spaces in the query.
Bluetooth devices without a name can be found by their displayed address.
Results follow new scan discoveries and name changes while searching.

Use the **×** button or Esc while typing to clear the search and show the full
list again. No results shows a message; disabled or missing adapters retain
their device status. Search clears when the card closes or its adapter changes
or is disabled. The query belongs to that card and is not saved.

## Public Wi-Fi login portal

For a connected open Wi-Fi network or a detected captive portal, **Login portal**
appears beside **Advanced Wi-Fi** (or **Back to Wi-Fi**) in the popup, Quick Control
and Wi-Fi settings. Press it
to reopen the public network's sign-in page when a login session expires.
It stays hidden on ordinary private Wi-Fi. Open networks retain the manual action
when automatic portal detection is disabled. Secured networks and networks with
unknown security show it only when NetworkManager reports a portal and no wired
or USB-tethered connection is active, since the native portal status covers the
whole computer. Wi-Fi being off, disconnected or removed also hides the button.

The portal status uses the existing native
[Quickshell 0.3.1 connectivity API](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/Networking/).
RusticQ does not enable connectivity checking or add background polling.

The button asks the default browser to open `http://neverssl.com/`, allowing the
hotspot to redirect the HTTP request to its login page. Complete the login in the
browser. If the hotspot does not redirect, use its provided login address. The
button leaves the Wi-Fi connection and saved profile in place. A browser launch
failure shows a retryable error with the address to open manually.

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
