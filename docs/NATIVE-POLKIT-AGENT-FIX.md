# Real Polkit agent for RusticQ Beta 1 (Omarchy Quattro)

## Root cause

Omarchy Quattro hosts its Polkit agent inside **omarchy-shell** (`shell/plugins/polkit/PolkitAgent.qml`), not necessarily a standalone `hyprpolkitagent` user service. Replacing omarchy-shell with RusticQ removes Omarchy's agent; checking `/proc` for `hyprpolkitagent` incorrectly declares that no agent is available. This leaves `pkexec` with no GUI authentication handler and causes `/dev/tty` errors from the package manager.

## Fix

`modules/main/NativePolkitAgent.qml` is instantiated once, at shell startup, as a persistent `Scope` containing Quickshell 0.3.x's **native** `Quickshell.Services.Polkit.PolkitAgent`. This object handles actual Polkit requests through the registered PolicyKit listener, passing the PAM conversation directly to the native `AuthFlow`. The private TextInput is visible only for requests that need a textual response, uses password echo by default, and clears on submit/cancel/success/failure. Fingerprint support is controlled by PAM. Nothing is sent to Python, copied to the clipboard, logged or persisted.

The package confirmation FloatingWindow remains the **first dialog**. The redundant non-privileged "System Authorization" layer is bypassed; the **second dialog** is the real native Polkit/PAM prompt. After confirming the package, the helper sends a harmless pkexec probe (`/usr/bin/true`) to verify that a registered Polkit agent can complete an actual authorization. If authorization fails, package installation is **blocked**. This initial authorization is **not** a reusable root token; the real pacman step may prompt again.

When another graphical agent already owns the listener, native Polkit may log a registration conflict. Do not terminate another agent automatically. Only one agent per session can register. Avoid running simultaneous separate RusticQ instances or Omarchy shell instances on the same desktop.

## Debug on your Hyprland session

```bash
cd ~/dev/quickshell
python3 scripts/rustiq-package-manager.py auth-capabilities
qs -p .
# in another terminal, non-destructive real Polkit/PAM test
pkexec /usr/bin/true
```

If no dialog shows, read `qs` logs and `journalctl -b -u polkit --no-pager | tail -50` for registration or PAM errors. If the native Polkit module is unavailable or Quickshell fails loading the configuration, restore the previous build; do not remove the system Polkit daemon or change PAM blindly.

### Deployment

For a permanent RusticQ shell, update `~/.local/share/rusticq/shell` using the existing Shell Updates → Reapply Local command **after** testing on the development instance and ending duplicate shell processes. This change does **not** edit `/usr/share/omarchy/default`.
