# RusticQ Shell Updates

Separate from `rustiq-updater.py`, which **only** updates Arch/Omarchy packages.
This feature manages RusticQ's Quickshell **source tree** without sudo or
changing system-level Omarchy files. Successful UI installations reload the
updated shell in place, using Quickshell 0.3.1's native reload API.

## Settings → Integration → Shell Updates

* Choose **DEV** to update `~/dev/quickshell`, or **PERMANENT** to update the
  existing installation at `~/.local/share/rusticq/shell`.
* **Reapply Local → Install local** — stages an updated copy of
  `~/dev/quickshell` and installs it into the permanent shell. The button click
  authorizes installation; no confirmation phrase is needed in the UI.
* **Check GitHub** — fetches GitHub Releases **metadata only**, including prereleases.
  This happens once when Settings → Integration is opened and can be requested again.
  The optional tag field accepts `beta-1` (or other published release tags).
* **Install update** — reviews the fetched release and destination, then installs
  it with the second **Install update** button. Beta releases and downgrades
  require the existing risk checkbox.
* **Fetch & install** — checks the selected release and installs it to the
  selected target in one action. The fetched tag is pinned before download.
  Beta releases and downgrades open the risk review instead of installing
  immediately. Failed fetches never start an install. Automatic periodic checks
  continue to fetch metadata only.
* **Rollback Shell** — restores the previous installed shell from a retained
  backup after confirmation `ROLLBACK SHELL`.

GitHub repository: https://github.com/thirteenalter/rusticq
Example tag: https://github.com/thirteenalter/rusticq/releases/tag/beta-1

Downloads prefer a full asset ending in `-full.zip` (produced by
`tools/build-release.py`) or named `quickshell.zip`/`rusticq.zip`, **with a valid
GitHub API `digest: sha256:<hex>` field**, or a same-release `SHA256SUMS(.txt)`
asset listing the ZIP. Archive entries must be rooted under `quickshell/` and
contain required RusticQ modules. An official GitHub source ZIP is also
supported when release assets are absent; this fallback has no independently
published SHA-256, and the UI identifies it accordingly. Patch-only ZIPs are
never installed. Download uses HTTPS and
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

After a successful UI installation or rollback, the running target reloads
automatically without starting a second instance. Automatic source watching is
paused while files are staged and replaced, then restored. Updating another
running target uses its `rusticq reload` IPC action. If that target is not
running, the files are ready for its next launch; the UI reports that no active
instance accepted reload. An old shell that predates this IPC action needs one
manual reload to start using the new workflow.

The settings page displays `100%` only for successfully installed files. Reload
errors retain the previous running configuration and are reported separately.
Valid external `user-settings.json` changes and successful imports also trigger
reload; saving ordinary settings does not. Direct CLI shell-update commands
retain their existing explicit confirmation phrases and report whether a reload
is needed.

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

`python3 tools/test_shell_updates.py` and
`python3 tools/test_shell_updates_dual_target.py` mock GitHub with isolated
temporary homes. `python3 -B tools/test_shell_install_ui.py` exercises the UI
with fake helpers. `python3 -B tools/test_config_reload_ui.py` uses isolated
offscreen Quickshell instances to check external settings, atomic directory
replacement, IPC reload, unchanged PIDs, and invalid-config recovery. These tests
do not update the host installation or download real releases. Real download,
Hyprland windows and monitor hotplug still need desktop verification.
