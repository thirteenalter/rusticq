# Package permissions: actual two-stage GUI + native Polkit authentication

## Fixed regression

The old handler waited until the Yay AUR build finished before starting the
privileged pacman operation. If no native GUI agent was registered, `pkexec`
tried its fallback textual agent on `/dev/tty`. A Quickshell-launched process
has no controlling terminal, producing `Error creating textual authentication
agent: Error opening current controlling terminal`. The older LazyLoader
for the second layer could also be destroyed during the first window's
focus transition.

## New behavior

1. The user clicks **Install** and accepts the first floating
   **Package Confirmation** window on the Settings workspace. Nothing is
   installed or elevated at this point.
2. After the first window disappears, a persistent Wayland fullscreen
   **System Authorization** layer opens on the Settings screen. The layer
   shows the provider, exact package, and available authentication methods.
   **Cancel** or Esc aborts the operation.
3. **Open system authentication** closes the layer and invokes
   `rustiq-package-manager.py authorize <provider> <operation> <package>`.
   The backend reuses a running Polkit agent; if none is found, it attempts to
   start only the installed `hyprpolkitagent.service` via `systemctl --user`.
   It never starts competing agents.
4. The backend requests native Polkit authorization using
   `/usr/bin/pkexec --disable-internal-agent /usr/bin/true`. This intentionally
   executes a harmless, system-owned executable and makes Polkit display its
   password/fingerprint dialog **before** Yay builds an AUR package.
   Denial/error prevents package execution.
5. After success, Yay builds unprivileged. Its *pacman-only* calls continue to
   use `/usr/bin/pkexec --disable-internal-agent` via Yay `--sudo` and
   `--sudoflags`; policy settings may require a second password/fingerprint
   confirmation at that later stage. Pacman installation calls use the same
   no-terminal-fallback rule.

**Security:** RusticQ does not display a password entry field or implement
its own PAM conversation. Only the installed trusted Polkit agent handles
credentials. A native authentication window will not appear until the
existing agent can register successfully. A missing/failed agent is reported
with actionable instructions, and **no package operation starts**.

## Diagnostics for Omarchy

```bash
systemctl --user status hyprpolkitagent.service
systemctl --user start hyprpolkitagent.service
journalctl --user -u hyprpolkitagent.service -n 50 --no-pager
python3 scripts/rustiq-package-manager.py auth-capabilities
```

The `auth-capabilities` operation is read-only. Avoid running more than one
Polkit agent. For fingerprint support, the device must be enrolled and PAM
for Polkit configured appropriately; a fingerprint symbol in the GUI does
not create/enroll a fingerprint or guarantee support.

## Testing

Run `python3 tools/test_package_two_stage_native_auth.py` and
`python3 tools/test_package_polkit_handoff.py`. The tests mock privileged
operations. Real authentication on the user's Hyprland session must still be
verified interactively.
