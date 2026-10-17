# RusticQ Alpha 4 RC5 — Setup and dependency manager update

- Rebuilt README as a current RC5 overview rather than an RC3 hotfix log.
- Added `FEATURES.md` and `docs/{INSTALLATION,DEPENDENCIES,PROJECT-STRUCTURE,TROUBLESHOOTING}.md`.
- Added a user-local, backup-on-upgrade Arch installer `scripts/install.sh`; no installer runs from ZIP extraction.
- Added publish-ready HTTPS, SHA-256-checked `scripts/bootstrap.sh` without a made-up release URL.
- Added official-Arch package allowlist `config/dependencies.json` and read-only dependency inspection plus confirm-in-terminal installs in `scripts/rusticq-dependencies.py`.
- Settings → Integration now separates optional package installation from reversible permanent Omarchy integration.
- Font loaders use system font fallbacks if the previous distribution's bundled TTF paths are not present.

**Compatibility:** The RC5 shell is intended for Quickshell 0.3.1. This update is not a compositor replacement or an Omarchy autostart change. Runtime QML testing on the target device is still necessary.
