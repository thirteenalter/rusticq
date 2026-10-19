# RusticQ Beta 1 · GUI package authorization & GitHub version selection

## Installed Apps: Pacman, Yay/AUR and Flatpak

The existing confirmation floating window continues to require a deliberate install/remove approval. It now explains that the next authorization step is **the operating system’s Polkit authentication agent**, not an input controlled by RusticQ. Pacman uses `pkexec /usr/bin/pacman` with validated package names; Yay builds AUR packages as the unprivileged user and uses `--sudo /usr/bin/pkexec` for privileged pacman phases. System Flatpak installations also use their own Polkit helper; Flatpak `--user` installations do not require administrator credentials.

**Fingerprint or password:** Polkit calls PAM. Whether fingerprint works depends on an enrolled fingerprint and `/etc/pam.d/polkit-1`, not on the RusticQ UI. No credential is passed to Python, QML, `sudo -S`, environment variables or logs. Never launch a second Polkit agent when Omarchy already has one. If no system dialog appears, inspect the user-session agent (`systemctl --user status hyprpolkitagent.service`) and verify Polkit is installed. The new Settings status includes a read-only capability hint, not a definitive proof that a native prompt will display.

**Yay invalid option `nocolor`:** Previously a version-specific `yay -Sia` preflight could fail and mix ANSI terminal color escapes into the error. This release verifies the exact package through the official HTTPS AUR RPC info endpoint (`aur.archlinux.org/rpc/v5/info`) without invoking Yay’s metadata flags. The actual build uses `yay -S --aur ...` as a regular user, with supported noninteractive review options and `pkexec` only for Pacman. Terminal escape codes are stripped from errors. A failing local Yay/Pacman configuration still needs repair in the user's OS; RusticQ will show a targeted error rather than claim the package is unavailable.

> AUR PKGBUILDs are third-party scripts with user privileges. The confirmation window links to the source. It is not safe to treat installation as fully audited just because an AUR package has a valid name.

### CLI diagnostics (read-only)

```sh
python3 scripts/rustiq-package-manager.py auth-capabilities
python3 scripts/rustiq-package-manager.py search-source yay ventoy-bin
```

## Shell Updates: GitHub versions

Settings → Integration → Shell Updates now loads **published GitHub releases**, including prereleases, using the backend `releases` CLI, which already existed. The scrollable list shows version names/tags, flags beta/alpha/RC/prereleases as `BETA / RISK` and disables unavailable assets. Clicking a version checks its specific tag before enabling the Update button. A manual tag remains possible but must first be checked; metadata from a different tag cannot authorize an installation. A beta/prerelease update additionally requires an explicit risk acknowledgment in the existing text-confirmation section. Rollback history and DEV/Permanent target selection remain unchanged.

```sh
python3 scripts/rusticq-shell-updates.py releases
python3 scripts/rusticq-shell-updates.py check --tag beta-1
```

The release list is online data. If GitHub cannot be reached, the UI displays an error and allows retrying. **No download or installation happens automatically** as a result of fetching versions. Actual versions/assets cannot be tested offline. Existing safeguards for ZIP paths, checksums and rollback are retained. The official GitHub source ZIP fallback does not provide an independently published SHA-256; the UI makes that visible.

## Files changed

- `scripts/rustiq-package-manager.py`: AUR RPC info, stable Yay installation, read-only Polkit capabilities, clearer errors
- `modules/settings/pages/SettingsInfoPage.qml`: graphical authorization status and instructions
- `modules/main/PackageConfirmationWindow.qml`: system-auth explanation in existing confirmation dialog
- `modules/settings/pages/SettingsIntegrationPage.qml`: release list, selected-tag verification, beta warning/acknowledgment
- `tools/test_gui_auth_release_picker.py`: isolated regression tests
