# Beta 1 — Full-height Wi-Fi Advanced + focused-monitor QR Overlay

- Replace 335px internal Advanced viewport with full intrinsic-height content;
  popup width, anchor, margins and parent styling stay unchanged.
- Compute popup height from real Wi-Fi card height, avoiding unused footer area.
- Add full-screen Wayland Overlay Wi-Fi sharing QR matching Power Menu styling.
- Separate QR generation/expiry/privacy cleanup from the Wi-Fi popup lifecycle;
  handle async close and rapid reopen without showing an outdated QR.
- Keep QR credentials exclusively inside temporary private file on runtime tmpfs.
- Add unit/static regression tests and document manual test flow.
