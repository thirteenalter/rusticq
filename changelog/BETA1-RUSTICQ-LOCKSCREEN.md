# Beta 1 — RusticQ Lock Screen

- Introduces a custom Hyprlock-based screen lock with PAM authentication and RusticQ branding, live clock, date, logo, username and password field.
- Provides private solid background (default) or the configured, validated local wallpaper, and Gruvbox accent synchronisation.
- Appearance page includes a non-locking visual preview, Render theme and Lock now actions.
- Power Menu Lock invokes the new secure screen lock, while the existing Omarchy ASCII Screensaver remains independent.
- Adds `lock` IPC and a registered Keyboard Shortcut Manager action, without editing Hyprland keybindings unless explicitly configured.
- Lock theme and logo written into an owner-only cache; no files are written under Omarchy or PAM configuration paths.
- Adds offline backend/security regression coverage. Test real locking/PAM on your Hyprland session before relying on it.
