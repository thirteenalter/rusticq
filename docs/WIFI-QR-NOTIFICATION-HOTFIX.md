# Wi-Fi / QR / Notification hotfix

- Wi-Fi network list scales up to 300 logical pixels when scan discovers APs. Advanced data remains unscrolled; only the list of networks scrolls when necessary. The popup remains anchored to the clicked icon and is capped by screen height.
- The Wi-Fi QR button closes its focused PopupWindow before opening the focused-monitor Wlr Overlay. The deliberate 260 ms transition avoids simultaneous focus grabs. The QR image uses private runtime storage and is erased on close or expiry; the image contains network credentials, so never share it publicly.
- Quick Control Notifications cards have a larger expanded area. A dedicated notification bell appears in the bar, with a separate enlarged notification popup, unread dot, and DND indicator. It may be hidden or relocated under Settings > Modules / Bar; saved icon arrangements from releases without the new bell are migrated without resetting order.
- `popup-notifications` is supported by existing bar shortcut dispatch.
- Settings / Omarchy files and user settings are not reset by extracting this patch.
