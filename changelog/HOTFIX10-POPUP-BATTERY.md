# Hotfix 10 — Popup indikator dan ikon baterai (Quickshell 0.3.1)

Dibangun dari ZIP Hotfix 9. Fitur Aether sync, Gruvbox, Quick Control, Settings, AI, dan bar modes tidak dihapus.

## Akar masalah

Log: `Could not convert argument 0 from Bar_QMLTYPE... to const QQuickItem*` pada `modules/main/Bar.qml:156`. `indicators.mapToItem(barWindow, ...)` salah karena `barWindow` adalah `PanelWindow`/`QsWindow`, bukan `QQuickItem`. Akibatnya fungsi `openMini(...)` tidak pernah terpanggil setelah klik indikator.

**Perbaikan:** `barWindow.mapFromItem(indicators, localX, 0)` (API Quickshell 0.3.1). Menghasilkan posisi relatif terhadap window bar, yang cocok untuk `PopupWindow.anchor.window` dan `anchor.rect.x`. Penempatan popup disetel sebelum `kind` berubah.

Di `IndicatorPopup.qml` assignment `width`/`height` diganti `implicitWidth`/`implicitHeight` sesuai API `QsWindow`, sehingga peringatan deprecated di log tidak lagi disebabkan oleh dua assignment ini. Popup tetap memakai widget shared `BarWifi`, `BarBluetooth`, `BarBattery`, `MiniAudio`; popup lain ditutup saat membuka Quick Control atau Arch AI.

## Ikon baterai (Material Symbols Rounded)

Source font: `assets/google.ttf` (font cmap dicek, tidak diubah). `BatteryService.icon` menggunakan glyph berikut:

| Status / persentase | Glyph | Unicode |
| --- | --- | --- |
| tidak ada baterai | `battery_android_question` | U+F302 |
| penuh / >= 97% | `battery_android_full` | U+F304 |
| sedang mengisi | `battery_android_bolt` | U+F305 |
| 0–3% | `battery_android_0` | U+F30D |
| 4–15% | `battery_android_1` | U+F30C |
| 16–30% | `battery_android_2` | U+F30B |
| 31–45% | `battery_android_3` | U+F30A |
| 46–60% | `battery_android_4` | U+F309 |
| 61–75% | `battery_android_5` | U+F308 |
| 76–96% | `battery_android_6` | U+F307 |

Fully charged diprioritaskan dari charging agar baterai 100% memakai ikon penuh. Persentase tetap dibaca dari UPower tanpa tebakan.

## Uji

```bash
python tools/verify-static.py
python tools/test_hotfix9.py
python tools/test_hotfix10.py
qs -p ./quickshell
```

1. Klik indikator Wi-Fi, Bluetooth, Battery, Audio bergantian; setiap klik harus menampilkan popup mini sesuai jenisnya. Klik ikon yang sama lagi untuk menutup.
2. Klik di luar popup, lalu buka ulang popup; periksa tanpa TypeError.
3. Klik Quick Control dan Arch AI sewaktu popup terbuka; popup seharusnya ditutup.
4. Coba mode Compact, Separated, Professional, dan multi-monitor jika tersedia.
5. Periksa ikon baterai di bar dan Quick Control untuk charge/full/low.
6. Cek `qs log -f`: warning QQuickItem conversion di `Bar.qml` dan width/height deprecated dari `IndicatorPopup` tidak seharusnya muncul.

**Batas uji:** tidak ada `qs` atau sesi Hyprland dalam container build. Pemeriksaan ini statis/regresi, bukan bukti runtime telah lulus.

## Referensi
- https://quickshell.org/docs/v0.3.1/types/Quickshell/QsWindow/
- https://quickshell.org/docs/v0.3.1/types/Quickshell/PopupWindow/
- https://quickshell.org/docs/v0.3.1/types/Quickshell/PopupAnchor/
