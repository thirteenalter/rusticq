# RusticQ Alpha 4 RC2 — Bar alignment and package management fix

No new release number. Built on Alpha 4 RC2.

- The bar now uses reusable zones. Every icon has Left / Center / Right placement, preserved in `barIconPlacements` inside `user-settings.json`.
- On a vertical bar, the same positions correspond to Top / Middle / Bottom.
- Reset-all restores original placement; module toggles and original data remain.
- Task View uses the Google `memory` glyph `e322` (alternative `stacks` is `f500`), AI/Arch launcher uses `network_intel_node` `f371`.
- Volume icon now changes at mute / zero / low / high volume; Wi-Fi, Bluetooth, battery and weather already use native dynamic icon logic.
- Installed Apps includes Manage on graphical app entries and Uninstall on pacman package rows. Installation from repository accepts an exact package name.
- Graphical app removal only proceeds when a pacman owner for the desktop entry can be identified.
- All mutations require explicit UI confirmation; removal requires typing the exact name. The transaction runs in an interactive terminal, and **risk is the user's responsibility**.
- Pacman removal uses `pacman -R` (no cascade, force, `--noconfirm`, or configuration purge). Arch install uses a full `pacman -Syu` transaction; Omarchy runs `omarchy update` first.
- A terminal being opened is **not** proof that install/uninstall succeeded. Refresh the package inventory to verify.

Test with `qs -p .` on Arch/Omarchy Quickshell 0.3.1. Graphical runtime and privileged system transactions cannot be executed in this build environment.
