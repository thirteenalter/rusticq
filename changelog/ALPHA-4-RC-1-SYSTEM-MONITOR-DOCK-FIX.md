# RusticQ Alpha 4 RC1 — System Monitor dock fix

Small source-only correction. No release/version bump.

- Removed the close (X) button from the System Monitor header. Close the floating window using your window manager (on typical Hyprland setups: the configured close-window shortcut). The window's visible state synchronizes back to `Store.systemMonitorVisible` so the monitor can be reopened.
- Replaced the Dock's **Task View** shortcut with **Monitor**, which opens the same **System Monitor** window as Shell → System Monitor, including Performance and Processes tabs. The icon remains the existing monitoring Material Symbol.
- Settings → Dock now labels the existing `dockTaskView` preference **System Monitor**. The stored key is deliberately unchanged to preserve existing preferences.
- Left the separate Task View button in the top bar unchanged. Only the **dock shortcut** is redirected.

## Smoke test on Hyprland

1. Launch RusticQ and enable Dock → System Monitor.
2. Click **Monitor** in the Dock. Verify the standalone System Monitor appears, without a close icon in its header.
3. Close the floating System Monitor using the compositor's window-close shortcut; click Monitor again to check reopening.
4. Use **Shell → System Monitor** and confirm that it opens the same window.
5. Confirm Settings → Dock still retains the toggle preference from earlier versions.

Static checks do not verify compositor window-closing behavior; test step 3 in your session.
