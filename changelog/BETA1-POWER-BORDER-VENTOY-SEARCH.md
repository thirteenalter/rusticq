# RusticQ Beta 1 — Yay CLI parity and power-menu border hotfix

- Yay search uses the **exact** `yay -Ss query` command, rather than `yay -Ss --nocolor query`, matching the working terminal command. ANSI coloring is already normalized by the parser.
- Search provider errors, including Flatpak timeouts, remain independently reported while other results are retained.
- Power menu stays on `PanelWindow` / `WlrLayer.Overlay` and adopts MiniLauncher's frame shape (`Theme.sectionRadius`, `Theme.borderaccent`, 1px border). The X/close icon is removed; Esc and backdrop clicks still close it.
- No modifications to Omarchy config, package installations, or permanent integration.
- Tests use actual-shaped Pacman/Yay CLI samples and mock the exact subprocess argv.
