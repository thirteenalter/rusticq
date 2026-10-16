# RusticQ Alpha 3 RC4 — Release Candidate

Target: Quickshell 0.3.1 / Qt 6 / Hyprland dengan konfigurasi Lua (Arch Linux).
Dibangun dari paket `rustiq-startup-fix.zip` (Alpha 3 RC3 + perbaikan BarMonitors.qml).

## Perubahan

- **Notification center:** singleton `NotificationCenter.qml` menerima notifikasi FreeDesktop dari aplikasi melalui `Quickshell.Services.Notifications`. Toast otomatis muncul selama sekitar 5,8 detik, histori maksimal 40 entri, DND menonaktifkan toast tetapi menyimpan histori, dan ada Clear All. Quick Control sekarang mempunyai accordion Notifications. Penggunaan API `NotificationServer` hanya bisa mengambil notifikasi ketika RusticQ berhasil memiliki nama D-Bus `org.freedesktop.Notifications`.
- **Task View:** ikon Google `monitoring` (U+F190) pada bar horizontal dan vertikal. Popup menampilkan CPU, memori, disk, load average, dan daftar 30 proses teratas menurut penggunaan CPU terkini beserta PID dan RAM. Semua read-only; tidak membunuh proses. Ada pintasan Task View melalui dock ke floating window lebih besar.
- **Monitor Apply:** `rustiq-display.py` menerapkan aturan `hl.monitor(...)` terpisah dan **memeriksa kembali** geometri, scale, dan resolusi dari `hyprctl -j monitors`. Bila perintah diterima tapi layar tetap di posisi lama, tampil pesan mismatch, bukan klaim sukses. `Export Lua` menyimpan snippet saja dan tidak menimpa konfigurasi Hyprland. Fallback `nwg-displays` tetap tersedia.
- **Settings Search:** kotak pencarian pada Settings, hasil indeks lintas kategori, dan navigasi ke pengaturan yang cocok (margin, modul, widget, dock, mode bar). Kata kunci dan tab terkait tersedia tanpa menggulir dari awal.
- **Margin Slider:** komponen reusable `MarginSlider.qml` dengan jalur rail/knob yang berkoordinat sama. Preview diterapkan selama drag, nilai disimpan saat mouse dilepas, tetap 0–32 px per mode.
- **Desktop widget catalog:** Clock, Calendar, System (CPU/RAM). Masing-masing punya toggle. Panel memakai `WlrLayer.Bottom`, di bawah aplikasi normal; akan tetap tersembunyi bila ada window maksimal menutupinya. Tidak menginstal plugin pihak ketiga; ini katalog widget bawaan yang modular.
- **Custom dock:** panel bottom dengan handle hover; bisa diaktifkan, diatur auto-hide, dan pilih shortcut Files, Browser, Settings, Task View, AI satu per satu. Default dock off. Pada posisi bar Bottom dock ditaruh lebih tinggi. Peluncuran hanya memakai daftar aksi bawaan.

## Instalasi

Cadangkan folder RusticQ lama beserta `user-settings.json`, lalu ekstrak paket lengkap ini ke **direktori baru**. Dari root folder yang berisi `shell.qml`:

```bash
qs --version
qs -p .
```

**Jangan menimpa `user-settings.json` lama tanpa backup.** Properti RC4 yang tidak ada di file konfigurasi lama akan menggunakan default aman (semua desktop widgets dan dock OFF).

## Smoke test di Hyprland

1. `qs -p .` harus memuat konfigurasi tanpa `Type ... unavailable` dan tanpa `Unexpected token`.
2. Kirim `notify-send 'RusticQ RC4' 'Toast check'` (paket Arch `libnotify`). Toast muncul dan histori terlihat di Quick Control → Notifications. Jika Dunst/SwayNC/Mako aktif sebagai notification daemon, berhentikan daemon tersebut secara sementara **hanya bila ingin mengalihkan notifikasi** ke RusticQ; jangan jalankan dua notification server sekaligus. Uji DND dan Clear.
3. Klik ikon monitoring di sisi kanan bar atau rail kiri/kanan. Verifikasi CPU/RAM/disk dan PID/process table berubah setiap 3 detik. Konfirmasi output helper manual: `python3 scripts/rustiq-processes.py`.
4. Settings → Displays → Refresh, susun dua monitor, Validate lalu Apply; cek `hyprctl -j monitors`. Bila pengaturan tidak benar-benar berubah, baca pesan readback; ekspor ke `~/.config/rustiq/monitors.lua` atau gunakan `nwg-displays`. Backup konfigurasi monitor sebelum Apply.
5. Settings → Bar & modules: coba Search `margin`, `desktop`, `dock`; klik hasil dan pastikan navigasi. Drag slider margin, lalu cek nilai dan bar bergerak realtime.
6. Aktifkan Calendar/System/Clock desktop widgets satu per satu; lihat di desktop kosong (di belakang jendela aplikasi). Widget tidak menerima input klik secara luas di luar kartu.
7. Aktifkan Dock lalu coba auto-hide. Hover handle pendek di tengah bawah layar; cek semua shortcut aktif dan toggle item dari Settings. Pada bar Bottom periksa overlap.
8. Uji monitor ganda; panel popup, notification toast, bar, dock dan desktop widgets harus dievaluasi pada masing-masing monitor.

## Verifikasi yang dilakukan dalam lingkungan build

```bash
python3 tools/verify-static.py
python3 tools/test_rustiq_rc4.py
python3 tools/test_rustiq_alpha3_rc3.py
python3 tools/test_hotfix10.py
```

Pemeriksaan ini hanya struktural dan mock offline. Tidak ada sesi Hyprland dan executable `qs` di lingkungan build, sehingga tidak ada klaim startup atau fidelity UI nyata yang sudah diuji. Masalah runtime pertama silakan kirim melalui `qs log -f`.

## Keterbatasan RC4

- Notifikasi bergantung pada kepemilikan D-Bus notification service. Histori disimpan dalam RAM selama sesi, bukan disimpan permanen.
- Mode monitor tertentu atau versi Hyprland yang berbeda masih mungkin menolak `hl.monitor`; readback akan melaporkan kegagalan. Ekspor Lua tidak otomatis di-`require` oleh konfigurasi Hyprland.
- Task View bersifat read-only. CPU per proses diperkirakan dari dua sampel `/proc` sekitar 200ms; penggunaan singkat bisa terlihat nol.
- Dock belum memiliki drag-and-drop reorder atau deteksi aplikasi yang sedang aktif. Shortcut dapat ditoggle secara individual di Settings.
- Desktop widgets merupakan modul bawaan, belum sistem plugin arbitrer yang mengeksekusi kode pihak ketiga.
