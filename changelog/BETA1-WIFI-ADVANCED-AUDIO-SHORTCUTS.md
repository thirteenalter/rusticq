# RusticQ Beta 1 · Advanced Wi-Fi, Audio & Shortcut override

- Wi-Fi popup: Advanced diagnostics, per-interface download/upload throughput, IPv4/gateway/DNS fields, secure Wi-Fi sharing QR, editable IPv4 DNS with rollback, existing popup width/anchor/padding unchanged.
- Audio popup: height calculated from actual content; no artificial bottom whitespace. Consistent `Theme.sectionPadding` at all edges.
- Omarchy Quattro shortcuts: use `o.rebind` for replacement of existing keys; allow `SUPER+ESCAPE` after GUI warning/confirmation; retain the original user file and line-level backups across restore and reassignments.
- Backup and restore do not edit the Omarchy distribution Lua files, do not bypass config error checks, and do not install autostart rules.

Base: `rusticq-beta1-shell-menubar-keyboard-full.zip`. Patch extraction goes to `~/dev` (includes the `quickshell/` prefix).
