# Hotfix: Restore Omarchy → reinstall refused at 43%

Earlier Beta 1 releases rejected the directory
`~/.local/share/rusticq/shell` if it lacked either `shell.qml` or
`scripts/rustiq-desktop-integration.py`. After a restore, interrupted updater,
or partial archive extraction, that directory can survive without an active
integration manifest. The rejection occurred **after the default/user backup
was verified (43%)** and **before overwriting any live Hyprland startup file**.

## New behavior

After the explicit `ENABLE RUSTICQ` confirmation and verification of Omarchy
backups, the installer checks the exact installed shell location. It now
archives an existing ordinary directory (including incomplete or empty
folders) **intact** under
`~/.local/state/rusticq/integration/stale-install-history/<timestamp>/shell`.
It then installs the new shell from the local source. No old files are removed
from the recovery archive, and existing original Omarchy backup data is not
modified.

Protection rules:

- The integration manifest **and** managed startup hook must both be absent.
- Symlinked installed shell paths and malformed shim/starter files fail closed.
- If a live `quickshell`/`qs` process has the installed shell path in argv,
  the installer refuses to move it. **Log out and back in** after restoring
  Omarchy before trying again; do not kill or remove a running shell's files.
- All transformations are prepared before moving orphan files. If copying or
  installing the new shell fails, the incomplete new copy is discarded and the
  old directory is restored to its former path.
- `status` now returns `reinstall.shell_state` and `reinstall.shell_note` to
  distinguish `partial`, `known`, `in_use`, `symlink`, and other cases.
- Recovery archive contents might contain user settings. It remains inside
  private integration history and should not be shared publicly.

## Diagnose safely

```sh
cd ~/dev/quickshell
python3 scripts/rustiq-desktop-integration.py status
ls -la ~/.local/share/rusticq/shell
pgrep -af 'quickshell|qs -p'
```

If an old Quickshell instance is still running from
`~/.local/share/rusticq/shell`, log out to Omarchy and start the updated
source from `~/dev/quickshell` (one instance at a time) before enabling
permanent integration. The successful installation prepares the **next login**;
it does not force-restart the session.

## Source files

- `scripts/rustiq-desktop-integration.py` — orphan recognition, process guard,
  transactional parking/recovery, nonmutating diagnostics.
- `tools/test_reinstall_partial_shell_folder.py` — regression tests including
  partial directories, symlinks, running processes, and injected copy failure.
