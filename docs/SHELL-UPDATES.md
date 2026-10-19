# RusticQ Shell Updates (Beta 1)

Separate from `rustiq-updater.py`, which **only** updates Arch/Omarchy packages.
This feature manages RusticQ's installed Quickshell **source tree** without sudo,
changing system-level Omarchy files, or restarting your current desktop session.

## Settings → Integration → Shell Updates

* **Reapply Local** — stages an updated copy of `~/dev/quickshell` and re-installs
  it under `~/.local/share/rusticq/shell` after confirmation `REAPPLY LOCAL`.
* **Check GitHub** — fetches GitHub Releases **metadata only**, including prereleases.
  This happens once when Settings → Integration is opened and can be requested again.
  The optional tag field accepts `beta-1` (or other published release tags).
* **Update Shell (GitHub)** — after confirmation `UPDATE SHELL`, downloads the
  full release ZIP via `curl`, verifies SHA256, validates paths/contents, and
  replaces the installed shell. **It never applies patch-only ZIPs.**
* **Rollback Shell** — restores the previous installed shell from a retained
  backup after confirmation `ROLLBACK SHELL`.

GitHub repository: https://github.com/thirteenalter/rusticq
Example tag: https://github.com/thirteenalter/rusticq/releases/tag/beta-1

The GitHub release must have a full asset ending in `-full.zip` (produced by
`tools/build-release.py`) or named `quickshell.zip`/`rusticq.zip`, **with a valid
GitHub API `digest: sha256:<hex>` field**, or a same-release `SHA256SUMS(.txt)`
asset listing the ZIP. Archive entries must be rooted under `quickshell/` and
contain required RusticQ modules. The app deliberately declines an update if
assets, checksum, or structure are unavailable instead of guessing an asset
URL. For a `beta-1` release with no full ZIP asset yet, attach the ZIP and
checksums produced by the release build workflow. Download uses HTTPS and
curl's restricted HTTPS redirects; it does not run remote shell commands.
A checksum published by the same repository verifies integrity, but is not an
independent signature of its publisher.

## Where changes go

* Installed shell: `~/.local/share/rusticq/shell/`
* Previous complete shell: `~/.local/share/rusticq/shell-before-update-<timestamp>/`
* Update status (read-only in UI): `~/.local/state/rusticq/shell-updates/status.json`
* Permanent startup hook and Omarchy backup **are not modified** by shell
  updates. `~/.config/hypr`, `~/.config/omarchy`, and
  `~/.local/state/rusticq/integration/backup` are untouched.
* The active installed `user-settings.json` and `app-usage.json` are carried
  forward during install and rollback. Other custom files removed from the
  new release remain accessible in the previous-shell backup and can be merged
  manually; they are never silently deleted from backup history.
* Update is a same-filesystem staging-and-rename transaction. If extraction
  fails, nothing is changed. If install fails after staging, previous shell is
  restored. An existing operation lock prevents concurrent updates.

**Installed ≠ running.** The current Quickshell process is not killed. Log out
and log in again (or carefully restart the single Quickshell instance) to
activate updated code. The settings page displays `100%` only for successfully
staged+installed files, not for the running-session version.

## CLI (same code as Settings)

```sh
cd ~/dev/quickshell
python3 scripts/rusticq-shell-updates.py status
python3 scripts/rusticq-shell-updates.py check --tag beta-1
python3 scripts/rusticq-shell-updates.py reapply-local --confirm 'REAPPLY LOCAL'
python3 scripts/rusticq-shell-updates.py update-shell --tag beta-1 --confirm 'UPDATE SHELL'
python3 scripts/rusticq-shell-updates.py rollback --confirm 'ROLLBACK SHELL'
```

`check` requires internet access, GitHub API availability and `curl`; it cannot
infer whether a manually installed, untagged build is newer than a release.
When the current installed tag is unknown, Settings displays the candidate
release but doesn't claim it is a *newer* version.

## Tests

`python3 tools/test_shell_updates.py` mocks GitHub and uses isolated temporary
homes. It never downloads real assets or restarts, reboots, or logs out of the
host session. This environment cannot run Quickshell and does not have working
external DNS, so real GitHub download and GUI-runtime integration must be
verified on the user's Arch/Omarchy machine.
