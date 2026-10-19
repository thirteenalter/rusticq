# RusticQ Beta 1 — Phase 2 Major Update

- Existing launcher now supports opt-in Settings search, emoji search, local wallpaper search, screen color picker, and private offline OCR.
- Existing calculator adds compatible SI/imperial unit conversions, with temperature conversions.
- App search relevance and bounded typo tolerance improved; AppUsage tie-breaks retained.
- Doctor checks optional tool capabilities without starting services.
- Integration dependency manifest includes hyprpicker, tesseract and libnotify.
- Reproducible full+patch packaging script, SHA256 manifest, and offline GitHub CI workflow.
- Updated 50-feature matrix/report and regression tests. All new tooling is user-space; no external uploads, no Omarchy startup changes.

**Not implemented:** complete 50-feature roadmap; full Unicode emoji database, thumbnail wallpaper UI, locale-aware unit conversion, per-app PipeWire stream mixer, secure PAM agent, plugins. Live compositor verification pending.
