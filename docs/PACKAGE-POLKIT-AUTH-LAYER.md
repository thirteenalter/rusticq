# Package authorization layer (Beta 1)

Installed Apps has two consent steps: its existing per-package confirmation
(including explicit typed confirmation for removal), then a full-screen
**System Authorization** layer styled after RusticQ Power Menu. The latter
shows the package/provider and explicitly hands off to the **existing**
system Polkit/PAM authentication agent when the user selects
**Open system authentication**. The overlay closes and releases Wayland focus
before invoking `pkexec`; no credential fields are added to RusticQ.

Why not implement a password TextInput? A password in shell QML would be
handled outside Polkit's registered authentication flow and would not by
itself authorize pacman. A second Polkit agent could conflict with Omarchy's
active agent. Instead the registered agent shows the actual password prompt
or fingerprint scan if fprintd/PAM enables it.

Yay runs as the unprivileged user and uses `--sudo /usr/bin/pkexec` for
privileged pacman phases. Removed the unsupported `--nosudoloop` flag, which
some Yay versions forward to pacman, producing `invalid option 'nosudoloop'`.
No arbitrary root-level shell script or `sudo -S` is used.

## Troubleshoot when the native dialog does not appear

```sh
cd ~/dev/quickshell
python3 scripts/rustiq-package-manager.py auth-capabilities
pgrep -af 'hyprpolkitagent|polkit.*authentication-agent'
yay --version
yay -Pg
```

Check `pkexec` and **one** registered Polkit agent. Omarchy commonly manages
its own Polkit agent. Fingerprint requires enrolled prints and a compatible
`/etc/pam.d/polkit-1` configuration. Avoid launching duplicate agents.
Do not test `pkexec` with arbitrary user-controlled code as root. Only the
validated pacman binary is elevated for package transactions.

## Testing

`python3 tools/test_package_polkit_handoff.py` checks `--nosudoloop` removal,
confirmation approval/handoff, sensitive-input exclusions and Wayland timing.
Real fingerprint, Polkit prompt focus and package installs require testing
in the user's active Hyprland session.
