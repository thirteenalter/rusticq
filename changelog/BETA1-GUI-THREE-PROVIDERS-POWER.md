# RusticQ Beta 1 — GUI Three-Provider Search & Power Menu

- Extend existing Installed Apps page with read-only simultaneous Pacman/Yay/Flatpak search and provider filters.
- Pacman GUI transactions are unchanged. Yay/AUR builds run as an unprivileged user with graphical Polkit for pacman phases; Flatpak uses its own permission model. No automatic terminal launch.
- Preserve package install/uninstall confirmation and provider through Store. New GUI results show installed state and precise package source.
- Replace nonfunctional PowerMenu stub with centered floating Wayland overlay, live keyboard focus, 6 real system actions and a second confirmation step.
- Access via Shell → Power menu, IPC `quickshell ipc -p . call rusticq power`, or a customizable shortcut action.
- Add `flatpak` and `hyprlock` to optional integration dependency catalog, without enabling system daemons.
- No changes to permanent Omarchy integration snapshots/revert.

Known limitations: AUR scripts must be reviewed and may require interactive PGP input; Flatpak needs a remote; direct Quickshell/Hyprland/Polkit runtime testing is still required.
