# Popup focus, outside-click dismissal and weather

- Replace the bar indicator's competing Qt popup/compositor grabs with one
  anchored layer panel. It acquires keyboard focus briefly, settles to on-demand
  focus, then arms one outside-click grab. Pointer movement does not close it.
- Release ownership immediately on logical close, including during exit motion.
  Opening another bar popup or transient panel releases the previous popup.
  Wi-Fi QR and device settings hand off focus before opening their next surface.
- Add **Settings → Bar → Popup interaction → Open bar popups on hover**.
  `barPopupsOnHover` defaults to false, accepts only booleans and uses the existing
  settings JSON. Horizontal and vertical bar items share the same behavior.
  Hover waits 150 ms to avoid opening panels while crossing the bar; leaving
  the trigger or clicking it again in hover mode keeps the panel open.
- Preserve search autofocus without stealing focus from another chosen input.
  Hidden connectivity cards release their search input.
- Launcher, power and Wi-Fi QR backdrops distinguish panel padding from outside
  clicks; AI outside-click ownership also applies in its expanded mode.
- Parse wttr.in JSON with explicit Celsius units and validated current data.
  Show the reported city/country instead of raw coordinate labels, keep the last
  observation on failure, and expose refresh/error status. Short screens and
  long descriptions scroll. Location remains IP-based, including VPN effects.

No compositor configuration, authentication logic, release version or installed
shell copy is changed. See the validation notes in the implementation report;
physical multi-monitor clicks and monitor hotplug require desktop verification.
