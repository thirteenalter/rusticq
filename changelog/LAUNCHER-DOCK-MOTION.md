# Launcher/dock smooth motion fix

Unreleased, no version bump.

- Animate QML surfaces in stable native canvases; preserve transparent gaps and input regions.
- Fade dock contents through collapse; avoid per-frame Wayland resize/recentering.
- Prepare blur rules before opening, retain backdrop until exit completes, stabilize its alpha carrier.
- Use one animation owner for dock/launcher; begin entry after the first native frame.
- Keep the launcher warm after first use in normal mode, release it in low-memory mode.
- Load icons asynchronously and avoid unchanged app-index/delegate rebuilds.
- Add native motion/frame-submit regression and pixel halo/gap coverage.
- Hide inactive detail previews from the result layout so their unused column spacing disappears and results fill the available width.

[Measurements and validation](../docs/LAUNCHER-DOCK-MOTION.md).
