# Wi-Fi Advanced intrinsic layout and QR overlay

- **Wi-Fi Advanced:** expanded status, traffic, DNS and network details now use
  their intrinsic QML height instead of a nested 335px `Flickable`. The anchored
  Wi-Fi popup remains 368px wide and preserves its existing bar position.
  A long *network list* can scroll independently, but the Advanced controls
  do not sit inside a scrolling viewport. On displays too short to fit all
  controls physically, the popup is clamped within available screen height.
- **Wi-Fi QR:** Share / Show QR closes the small Wi-Fi popup and opens a modal
  full-screen `PanelWindow` at `WlrLayer.Overlay`, on the same physical monitor
  as the clicked Wi-Fi indicator, with the same dimming and border design used
  by Power Menu. QR generation happens in the overlay process (not the popup).
- **Privacy:** Wi-Fi credentials are never copied into QML or printed to stdout.
  A private PNG is created only upon request in `$XDG_RUNTIME_DIR/rusticq-wifi-qr/`,
  using the existing protected NetworkManager helper. It is unlinked when the
  overlay closes, loses focus or expires after 45 seconds. When the encoder is
  still running on close, cleanup waits for it to exit before unlinking.
  Never share a screenshot of the QR with someone you do not trust.
- **Controls:** Esc / Enter / Done or outside click closes the overlay.
  Audio, DNS transactions, the Power Menu, and the Omarchy shortcuts are unchanged.

If no QR appears, ensure NetworkManager has the password saved and install
`qrencode` or Python `qrcode` through the system's usual package manager.
The QR can be cleared manually with
`python3 scripts/rusticq-wifi-advanced.py qr-clear`.
