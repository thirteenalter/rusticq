# RusticQ Beta 1 — Wi-Fi Advanced, Audio and Shortcut Overrides

## Wi-Fi Advanced

The Wi-Fi indicator opens the existing 368px popup at its existing anchor. The
Advanced button expands *within the same popup* at its full intrinsic height
(without a separate Advanced scrolling area) for live interface Rx/Tx (bytes/s, not an internet speed test), connection info,
IPv4/IPv6 DNS, gateway, and manual IPv4 DNS. Opening the advanced panel does
not install packages or change network configuration.

**Share Wi-Fi via QR** closes the small popup and opens a centered full-screen
Wayland Overlay on the clicked monitor. It explicitly requests QR generation for the active
NetworkManager profile. It supports open / WPA personal networks; enterprise
networks and missing passwords fail closed. The password never passes through
Quickshell QML, stdout JSON, or an application log. The QR PNG includes the
password, so treat QR screenshots as secret. The PNG is stored inside
`$XDG_RUNTIME_DIR/rusticq-wifi-qr/` with private permissions, and is removed
when the QR overlay is closed or after 45 seconds. QR requires the
`qrencode` CLI or Python `qrcode` package. To force cleanup after a crash:
`python3 scripts/rusticq-wifi-advanced.py qr-clear`.

Changing DNS explicitly modifies the **active Wi-Fi profile** via `nmcli`
and reapplies it. Invalid IP values are rejected. If reapplying fails, the
previous DNS fields are restored. Only IPv4 DNS is edited here; IPv6 DNS is
informational. NetworkManager may require additional user authorization. Do
not apply custom DNS if your network requires special split-DNS/VPN routing.

## Audio popup

Collapsed popup height is determined by content; internal spacing uses
`Theme.sectionPadding`. No artificial minimum whitespace is added below
volume controls. Advanced PipeWire output/microphone controls are preserved.

## Omarchy Quattro shortcut override

RusticQ appends a marked block to the *user* `bindings.lua` using `o.rebind`
to replace existing shortcuts (including defaults). Core Omarchy Lua is not
edited. A private backup of the original user file is saved before the first
change, and matching original Omarchy/user binding lines are kept in an audit
file even after restore.

Sensitive combinations (`SUPER+ESCAPE`, `SUPER+BACKSPACE`) require explicit
confirmation in Settings → Shortcuts. Restore Selected removes only RusticQ's
binding for that action and reloads Hyprland, preserving other user changes.
If the desktop GUI cannot be opened, use a TTY and run:

`python3 scripts/rustiq-desktop-integration.py shortcut-revert --action power`

Replace `power` with the relevant RusticQ action. Check the registry with
`python3 scripts/rustiq-desktop-integration.py status`. Quickshell installed
through Omarchy permanent integration keeps the same managed bindings.

This change does **not** install persistent services or modify the original
Omarchy default files.
