# RusticQ release manifests

`VERSION` contains the active source tag, currently `beta-4`. Each documented
release has a separate JSON manifest under `config/releases/<tag>.json`.
`scripts/rusticq-release.py` validates these files and supplies metadata to the
Settings singleton, the CLI and the archive builder. The shell updater continues
to compare the `VERSION` of the selected source target, including older sources
that predate manifests.

## About

Settings → About displays the active release name, tag, date, channel and minimum
Quickshell version. Version history lets you select a documented release, read
its highlights and open its original local Markdown notes. The catalog is loaded
once locally; it makes no network requests. A failed active manifest is reported
with a reload button. An invalid historical manifest is skipped with a warning.

Historical entries are reconstructed from their referenced repository changelogs.
Their original tag spelling is retained where documented, including `rustiq-`
legacy identifiers. Missing dates are `null`, displayed as “Release date not
recorded”. Beta 1 Phase 2 is part of Beta 1; the repository does not establish a
separate Beta 2 release, so the catalog does not invent one. Source metadata and
historical notes do not verify whether a GitHub Release has been published.

## Adding a release

1. Add `config/releases/<tag>.json` using `schemaVersion: 1`, `tag`, `name`,
   `date` (ISO date or `null`), `minimumQuickshell`, `summary`, `changes` and
   `notes`. Use the existing manifests as examples. Names must match the tag,
   such as `beta-5` → `Beta 5` or `alpha-4-rc5` → `Alpha 4 RC5`.
2. Add the referenced changelog or documentation paths. Keep historical
   manifests and their notes intact.
3. Set `VERSION` to the new tag and update the current-release README text.
   QML, CLI and the default archive label need no version string changes.
4. Validate and build:

   ```bash
   python3 -B scripts/rusticq-release.py catalog
   python3 -B scripts/rusticq-cli.py version
   python3 -B -m unittest discover -s tools -p 'test_*versioning.py'
   python3 -B tools/test_release_about_ui.py
   python3 -B tools/build-release.py --out /tmp/rusticq-dist
   ```

The builder includes the selected release metadata in its checksum manifest.
`--label` can override the archive filename prefix without changing the release
identity. Full/patch archive behavior is unchanged. Publishing tags or uploading
GitHub Releases is a separate operation.
