# RusticQ Beta 1 — Feature Matrix Implementation Batch A

Safe additions to user-provided Beta 1 source; no rewrite, OS package install, or permanent Omarchy startup changes.

- #4 optional systemd user restart unit, 90s/3 start guard, never automatically enabled.
- #9 read-only Doctor CLI + Settings status, reuses existing notification doctor.
- #10 private JSON snapshots/atomic restore (CLI), Settings snapshot button.
- #16 launcher `=math` expressions via restricted Python AST, optional `wl-copy` for user-initiated copy.
- #48 RusticQ CLI status/doctor/config/ipc/watchdog using existing IPC whitelist and guarded Config Guard.

The full matrix remains partial/missing because comprehensive end-to-end tests are impossible without the target Hyprland system. See docs/audit/BETA1-REPORT.md.
