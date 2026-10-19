# RusticQ Beta 1 — Major Update, Phase 2

## A. Architecture (unchanged foundations)

The update is derived from the **user-uploaded Beta 1 Phase 1 full ZIP**, not the older RC4 snapshot. Shell entry remains `shell.qml`, app search/selection remains `modules/main/MiniLauncher.qml`, settings navigation remains `Store.showSettings`, and wallpaper changes still use the original `scripts/rusticq-wallpaper.py`. Phase 1 Doctor/Guard/CLI/watchdog are preserved. No daemon or compositor agent was introduced.

## B. Updated 50-feature matrix

The accompanying `BETA1-50-FEATURE-MATRIX.csv` records all 50 features with source evidence. Post-change status: **30 PARTIAL / 20 MISSING**. None are marked IMPLEMENTED without live end-to-end verification. This is a large *incremental* release, not a claim that all 50 roadmap features are finished.

| Feature ID | What changed | Outstanding |
| --- | --- | --- |
| #9 System Health Doctor | Added optional launcher tooling capability checks. | Deep D-Bus/portal/PipeWire runtime diagnosis. |
| #11 Universal Search | `:settings`, `:emoji`, `:wallpaper`, and action providers in the existing launcher. | Files, windows, workspaces, provider SDK. |
| #12 Smart Fuzzy Search | Bounded typo tolerance and relevance-first ranking with existing AppUsage tie-breaking. | Large-index latency baselines and localization. |
| #15 Emoji & Symbol Picker | Search a compact fixed local emoji set, copy selected symbol. | Full Unicode database, categories, variants. |
| #16 Integrated Calculator | Length, mass, volume, duration, temperature conversions through explicit `=...` queries. | Richer conversion database/locale UI. |
| #17 OCR Screenshot | Select region → Grim → local Tesseract → clipboard. | Multilingual setup, in-app review, history. |
| #19 Color Picker | Hyprpicker HEX, computed RGB/HSL, clipboard copy. | Palettes/history. |
| #20 Wallpaper Search | Bounded personal-library scan + existing wallpaper setter. | Visual thumbnail preview, profile management. |
| #50 Reproducible Releases | Deterministic ZIPs, SHA manifest, CI static/tests. | Arch/AUR/Nix, full desktop CI. |

## C. Conflict & compatibility

- **No second launcher**: all providers extend `MiniLauncher.qml`; the ordinary DesktopEntries/AppUsage ranking remains in place, including pinned/frequent applications.
- **No alternate wallpaper manager**: the new search provider calls the existing setter after the user selects an image; symlinks/outside-home files are rejected.
- **No clipboard monitor/history**: clipboard is only written on an explicit selection; never reads passwords or password-manager buffers.
- **No screenshot upload**: OCR and color picker use local binaries only. The overlay closes before Wayland selection begins, avoiding capturing the launcher itself.
- **No privileged operations**: tools do not use sudo, alter Omarchy startup, or enable background services. Missing optional dependencies display errors.
- **Theme precedence**: wallpaper setter remains independent from Aether/manual palette selection; no automatic palette syncing added.

## D. Roadmap

- **P0 next**: live Hyprland/Omarchy smoke tests, verify trusted hyprlock/hypridle/polkit integration, safe hotplug handling, service owner conflict tests.
- **P1 next**: windows/files/workspaces universal providers, per-app PipeWire mixer, notification grouping/DND policy, data-safe config migration, accessibility focus/reduced motion.
- **P2 backlog**: encrypted clipboard, full emoji Unicode picker, notes/Kanban, screen annotation, calendar/CalDAV, time theme scheduling, plugin SDK, local AI, compositor adapters, package recipes. High-risk services should not be introduced without their trust boundaries.

## E. Implementation and verification

Added `scripts/rusticq-launcher-tools.py`, `tools/build-release.py`, `.github/workflows/static-validation.yml`, `tools/test_beta2_launcher_tools.py`, `tools/test_beta2_release_fuzzy.py`. Updated `MiniLauncher.qml`, `rusticq-calc.py`, `rusticq-doctor.py`, package manifest, relevant previous test expectations, README and docs/matrix.

- **New compulsory dependencies:** none.
- **Optional dependencies:** `hyprpicker`, `tesseract`, `libnotify`; existing `grim`, `slurp`, `wl-clipboard` and wallpaper daemon.
- **Online behavior:** zero new network calls; wallpapers searched only locally, no screenshot uploads.
- **Interaction:** app search still opens apps; `:settings` opens the existing Settings window; `:color`/`:ocr` spawn only upon user selection and close the launcher before screen interaction.

## F. Performance

Providers run on explicit `:prefix` queries, not in a persistent background process. Wallpaper scanner limits itself to 1,800 images and a shallow home-directory walk; results are capped at 48. Fuzzy scoring is limited to application-name tokens and one bounded edit distance search per token. CI builds are deterministic across repeated runs. **Actual idle RSS/CPU, Wayland animation latency and launcher response benchmarks cannot be measured in this headless container.**

## G. Remaining incomplete work

The 20 MISSING and 30 PARTIAL rows remain in the CSV. In particular, secure lock/PAM, Polkit agents, compositor-agnostic session management, clipboard encryption, replay recording, CalDAV, automation rules and plugin sandboxing are *not* claimed complete. Wallpaper thumbnails and Unicode-complete emoji search also remain pending.

## H. Final verification checklist

```bash
python3 tools/verify-static.py
python3 -m unittest discover -s tools -p 'test_beta2*.py' -v
python3 -m unittest discover -s tools -p 'test_beta1_feature_batch.py' -v
python3 -m unittest discover -s tools -p 'test_phase1_doctor_guard.py' -v
bash -n scripts/install.sh scripts/bootstrap.sh
```

Manual Wayland verification (not available here): open launcher and test `:emoji cat`, `:settings display`, `:wallpaper sunset`, `=5 km to mi`, and an intentional `:color` or `:ocr` action. Verify clipboard, theme side effects and window placement. Test in `qs -p .` before enabling permanent Omarchy integration.
