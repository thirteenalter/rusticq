# RusticQ — rustiq-alpha-1

**Nama aplikasi:** RusticQ  
**Nama rilis/ZIP:** `rustiq-alpha-1`  
**Basis kode:** Hotfix 10, Quickshell 0.3.1 / Arch Linux / Hyprland  
**Pewarnaan:** Independent Gruvbox atau Follow Aether (tetap tersedia)

## Perubahan visual dan interaksi

- Konsisten menggunakan **Google Material Symbols Rounded** dari `assets/google.ttf` untuk ikon antarmuka. Ikon Power Menu lama yang memakai kode Font Awesome telah diganti, termasuk ikon launcher AI dan tombol Quick Control.
- Tanggal, jam, dan cuaca sekarang punya ikon ukuran 16px, slot ikon 18px, teks Poppins Medium 12px, jarak ikon–teks 6px. Ketiganya berbagi `components/InfoSegment.qml` dan token di `config/Theme.qml`.
- Jam dan tanggal ditampilkan terpisah; tanggal mencantumkan nama hari (berdasarkan locale sistem), misalnya `Jum, 16 Okt`.
- Klik **jam** membuka mini widget jam detik aktual + tanggal lengkap (`MiniTime.qml`).
- Klik **tanggal** membuka kalender bulanan yang bisa dinavigasi (`MiniDate.qml`), dengan hari ini diberi aksen.
- Klik **cuaca** membuka mini widget temperatur, kondisi, terasa-seperti, lokasi, dan tombol refresh (`MiniWeather.qml`). Ikon bar ikut kondisi cuaca; bila belum ada data, ditampilkan placeholder `--°`.
- Mini widget tetap memakai `IndicatorPopup` yang dipakai Wi-Fi, Bluetooth, Battery, dan Audio. Popup dibuka tepat di bawah item yang diklik, menutup saat klik di luar, dan hanya satu popup aktif.
- Label Settings, info bar Professional, dan judul AI berganti menjadi RusticQ.

## Catatan kompatibilitas dan keterbatasan

- **Jangan ganti nama direktori proyek `quickshell/` secara otomatis**: ini nama direktori konfigurasi standar yang bisa dijalankan dengan `qs -p ./quickshell`. Identitas aplikasi di dalam sudah RusticQ.
- API `SystemClock`, `PopupWindow`, `QsWindow.mapFromItem()` dan `Process` mengikuti dokumen upstream Quickshell 0.3.1.
- Data cuaca berasal dari wttr.in lewat `curl` milik WeatherService sebelumnya, bukan servis cuaca baru. Perlu koneksi internet; lokasi berdasarkan layanan sumber cuaca. Refresh otomatis setiap 10 menit, tombol manual ada pada mini widget.
- Kalender hanya untuk melihat dan mengganti bulan; tidak mengubah event Google Calendar, sistem, atau file pribadi.
- Power Menu merupakan **prototipe tidak aktif** sejak sebelum rilis ini. Penggantian glyph **bukan** berarti aksi lock/reboot/shutdown yang masih placeholder telah diimplementasikan.
- Tidak ada pengujian GUI Hyprland dalam lingkungan build; hasil pemeriksaan yang tersedia adalah statis dan pemeriksaan glyph dari TTF. Jalankan sendiri di Quickshell 0.3.1.

## Menjalankan dan smoke test

```sh
unzip rustiq-alpha-1.zip
qs -p ./quickshell
# Jendela terminal kedua:
qs log -f
```

1. Pastikan nama hari, jam, suhu, dan ikon Material terlihat pada semua mode bar (termasuk Simple dan Clean Compact).
2. Klik satu per satu cuaca, jam, tanggal; cek posisinya, ikon header, pergantian bulan, dan refresh cuaca.
3. Klik Wi-Fi, Bluetooth, Battery, Audio dan lihat apakah popup Hotfix 10 masih berjalan.
4. Buka Full Settings/AI, lihat branding RusticQ dan mode warna Gruvbox/Aether.
5. Cek font sistem lewat `fc-scan quickshell/assets/google.ttf`, tetapi icon `Icon.qml` selalu memuat file dari assets langsung.
6. Untuk pemeriksaan source: `python3 quickshell/tools/verify-static.py`, `python3 quickshell/tools/test_rustiq_alpha1.py`.

## Berkas utama yang berubah

- `components/InfoSegment.qml` (baru), `Clock.qml`, `Weather.qml`, `Arch.qml`, `Wifi.qml`, `Bluetooth.qml`, `Battery.qml`, `Audio.qml`, `PowerButton.qml`
- `modules/main/Bar.qml`, `IndicatorPopup.qml`, `MiniWeather.qml` (baru), `MiniTime.qml` (baru), `MiniDate.qml` (baru)
- `modules/settings/SettingsWindow.qml`, `modules/ai/AiWrapper.qml`, `modules/power/PowerMenu.qml` (ikon saja)
- `services/WeatherService.qml`, `config/Theme.qml`

## API resmi

- [SystemClock 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell/SystemClock/)
- [PopupWindow 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell/PopupWindow/)
- [QsWindow 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell/QsWindow/)
- [Process 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process/)
