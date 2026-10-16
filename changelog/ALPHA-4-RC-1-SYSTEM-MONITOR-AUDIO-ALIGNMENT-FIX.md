# RusticQ Alpha 4 RC1 — System Monitor, Audio Input & Alignment Fix

No release number change. Based on `rustiq-alpha-4-rc1-floating-height-fixed.zip`.

## Changes

- **Shell → System monitor** now opens a dedicated `SystemMonitorWindow.qml` (Performance and Processes views) rather than launching `btop`/`htop` in a terminal. Process lists retain existing `SystemDashboard` behavior.
- New singleton `SystemMetrics.qml` samples read-only Linux counters every two seconds through `scripts/rustiq-system-metrics.py`.
- Performance charts: CPU, RAM, GPU usage (when supported by the driver), network RX/TX, and physical disk read/write. Hardware detail card also exposes Wi-Fi SSID/signal, GPU name/VRAM (when available), thermal sensor reading, and free disk space. All data is local; unavailable GPU metrics are marked N/A.
- Menu Edit/View/Share/Shell has one stable horizontal anchor, consistent icon slot widths, labels and trailing status/check positions. Display detail items are indented to the header label baseline, with a fixed-size right chevron.
- Quick Control → Advance → Audio now offers **Input device** selections (PipeWire sources, non-stream nodes) in addition to the pre-existing output device selection and microphone volume/mute. Audio card height follows actual content.

## Dependencies

- Existing Quickshell 0.3.1/Hyprland shell and PipeWire.
- Python 3 (standard library) for the system metrics helper.
- GPU utilization is available through `/sys/class/drm/*/device/gpu_busy_percent` on supported drivers or `nvidia-smi` if available. Unsupported devices show N/A rather than simulated usage.
- Network throughput is calculated from `/proc/net/dev` cumulative counters for active non-loopback interfaces. Physical block I/O uses `/sys/block/*/stat`. Rates are differences across observations, not guessed bandwidth.

## Test steps

1. Run `qs -p .` and open **Shell → System monitor**. Expect a new window with seven charts and a hardware detail section.
2. Verify charts move after a few seconds. For GPU, N/A is acceptable if the driver provides no utilization reading.
3. Switch to Processes. Verify CPU process list populates. Close the separate window using its X button.
4. Click Edit, View, Shell in the menu bar, checking popup left alignment, icon slots, labels, and selected bar-mode checks.
5. Open Settings → Displays; expand both monitors and check arrow placement, content indent and Apply section alignment.
6. Open Quick Control → Advance → Audio. Verify default input source, select another source if present, and check microphone volume/mute. Verify that the Audio card and sidebar scroll rather than clipping.

### Offline tests

```bash
python3 tools/verify-static.py
python3 tools/test_system_monitor_fix.py
python3 -m py_compile scripts/rustiq-system-metrics.py
```

**Runtime status:** The build environment does not contain the Quickshell executable or a Hyprland/PipeWire session. QML runtime, window-manager positioning and physical device changes must still be tested on an Arch desktop.
