# Native network speed test

Open **Advanced Wi-Fi** in the network indicator popup to reveal the separate,
aligned Speed Test card. Returning to the network list releases that card's space.
The popup follows their intrinsic height, stays within the selected monitor and
scrolls when the combined content exceeds available space. Wi-Fi search, native
NetworkManager controls, Advanced, hidden networks, portal login and secure QR
sharing retain their existing owners. Quick Control and device settings keep
their existing Wi-Fi cards.

Select **Test Speed** to start. A shared singleton retains the running process
and the last completed result while the popup is closed or opened on another
monitor. **Cancel Test** terminates the adapter and its backend process group,
restoring the previous completed metrics, if available. Results and last-test
time belong to this shell session and are not written to user settings. Nothing
tests automatically on open, reconnect, monitor changes or preference changes.

## Supported optional backends

- **Ookla Speedtest CLI**, executable `speedtest`, is preferred. RusticQ checks
  `--version` to distinguish it from similarly named tools, then requests
  `--format=jsonl --progress=yes`. Actual ping/download/upload events update
  the metrics and gauge. Machine-readable bandwidth is bytes/second, normalized
  to decimal Mbps with `bandwidth * 8 / 1,000,000`; latency is milliseconds.
  Obtain it from the [official CLI page](https://www.speedtest.net/apps/cli).
  Run `speedtest` in your own terminal first to review its license/privacy terms.
  RusticQ supplies no acceptance flags and closes stdin, so an uninitialized
  installation shows a setup message instead of accepting terms or waiting for input.
- **sivel speedtest-cli**, executable `speedtest-cli` (or a recognized `speedtest`
  alias), is a compatible fallback using `--json --secure --timeout 10
  --no-pre-allocate`. Its JSON speeds are bits/second, divided by 1,000,000.
  This backend provides final results only; the gauge stays unmeasured during
  preparation and moves to the actual final result. Its HTTP latency and
  throughput can differ from Ookla's socket tests, as documented in the
  [upstream README](https://github.com/sivel/speedtest-cli). This project is
  archived upstream; Ookla is recommended for new installations.

Python 3 is already a RusticQ dependency. No new Python packages, browser,
root privileges or automatic package installation are required by the adapter.
Installing a backend is a separate user action. `python3
scripts/rusticq-speedtest.py --probe` checks executable/version availability
without generating speed-test traffic. Click **Retry** after installing one.

Measurements use the active system route, including Ethernet or a VPN; they
do not bind to the Wi-Fi interface. Native NetworkManager connectivity gates
offline/captive-portal starts without adding polling or enabling connectivity
checks. A connected link does not guarantee internet access; backend failures
provide a retryable error. Speed tests use internet data and bandwidth; their
traffic volume depends on the backend and connection speed.

The adapter drains stdout/stderr asynchronously, limits line sizes, strips
private result fields (including IP addresses and result URLs), validates
finite nonnegative measurements, and commits results only after a successful
backend exit. It enforces a 120-second deadline; the QML service has a separate
130-second watchdog and an escalation timer for stuck cancellation. Raw backend
diagnostics are never forwarded into QML or logs.

## Appearance → Network Panel

| Preference | Default |
| --- | --- |
| Show Speed Test Panel | On |
| Show Speedometer Gauge | On |
| Enable Gauge Animation | On, subject to global animations |
| Enable Gauge Glow | Off; requires permitted RAGE reflection/effects |
| Show Last Test Time | On |
| Speed Test Panel Style | Classic Gauge |

**Classic Gauge** uses a Canvas arc, graduation marks and analog needle.
**Modern Arc** removes the needle and centers the digital result. **Compact**
releases the gauge and divider entirely and places the metrics horizontally.
Hiding the gauge releases its layout space in either larger style. The scale
automatically selects 100, 250, 500, 1000 Mbps or larger ranges without clamping
high-speed results. No timer generates simulated measurements or repaints an
idle gauge. Theme tokens, Poppins and existing glass surfaces resolve all colors,
padding, radii, effects and motion, including RAGE Exclusive palettes.

Preferences are validated booleans and the `classic`/`modern`/`compact` style enum
in `SettingsStore.qml`. Old settings inherit defaults; externally edited network
appearance preferences update live using the existing FileView mechanism.

## Validation

```bash
python3 -B tools/test_speedtest.py
python3 -B tools/test_speedtest_ui.py
python3 -B tools/test_wifi_audio_ui.py
python3 -B tools/test_wifi_qr_fullscreen_layout.py
python3 tools/verify-static.py
python3 tools/check-bar-modes.py
```

The adapter tests run real local fixture processes and validate parsing,
normalization, missing/conflicting executables, no acceptance flags, malformed
output, timeouts and cancellation of backend workers. QML tests use the production
components with a fixture CLI and native-connectivity fixture, isolated settings
and offscreen rendering. They do not perform real internet measurements.
Real CLI/server measurements, physical monitor hotplug, fractional scales and
desktop compositor behavior require a suitable local session and installed CLI.
