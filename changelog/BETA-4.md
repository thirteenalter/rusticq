# RusticQ Beta 4 (`beta-4`)

Date: 2026-11-13

## Release information and About

- `VERSION` selects the active JSON manifest in `config/releases/`.
- Settings and the CLI read the same validated manifest for the version name,
  tag, compatibility requirement, date and release highlights.
- About includes a version selector for documented Alpha and Beta releases,
  release highlights and links to their original local release notes.
- Historical manifests are reconstructed from the referenced repository notes.
  Unknown historical dates remain unspecified. Beta 1 Phase 2 is a feature
  batch, not evidence of a separate Beta 2 release; no Beta 2 is invented.
- Unreadable current metadata produces an explicit error with a retry action.
  Invalid historical entries are skipped with a visible warning.
- Replace stale branding instructions and RUSTIQ Settings labels with current
  RusticQ product information.
- Release archive labels default to the selected manifest; build manifests
  include the complete release metadata alongside archive checksums.
- Exclude local `.aws`, `.codex` and `.agents` directories from release ZIPs.

Quickshell 0.3.1 remains the compatibility baseline. Existing user settings and
installed desktop configuration are not migrated by this source update.
Updating source metadata does not publish a GitHub tag or Release.

## Verification

- Source structure and five bar-mode checks passed.
- Manifest/version parity, historical downgrade comparisons, archive packaging,
  launcher provider, shell updater and Cloud AI offline checks passed.
- Quickshell 0.3.1 offscreen checks opened the history menu, selected every
  documented version and verified error recovery and historical-entry warnings.
- A full source ZIP was built and checked for archive integrity, version parity
  and exclusion of local credentials and user settings.

Live Hyprland rendering, hardware interaction and multiple monitors were not
tested for this release update. No running or permanently installed shell was
replaced during verification.
