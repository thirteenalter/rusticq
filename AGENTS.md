# Panduan Agen

## Latar belakang proyek

**RusticQ (rustiq-alpha-1)** adalah aplikasi shell desktop berbasis **Quickshell**, QML, dan Qt 6
untuk Linux dengan compositor Wayland **Hyprland**. Baseline kompatibilitas
repositori adalah Quickshell **0.3.1**. Aplikasi menyediakan bar per monitor,
workspace, Quick Control, pengaturan tampilan, serta panel Cloud AI.

Identitas visual menggunakan Gruvbox Dark, font Poppins, dan Material Symbols
Rounded. Pertahankan konsistensi tampilan dan perilaku antar-monitor saat
mengembangkan fitur.

## Struktur proyek

- `shell.qml`: entry point; membuat bar per layar dan memuat panel melalui `LazyLoader`.
- `config/`: konfigurasi, tema, font, state UI bersama, dan penyimpanan pengaturan.
- `components/`: komponen QML yang dapat digunakan ulang.
- `services/`: integrasi Wi-Fi, Bluetooth, baterai, metrik sistem, cuaca, dan tooltip.
- `modules/main/`: bar utama.
- `modules/bar/`: sidebar Quick Control beserta kartu kontrolnya.
- `modules/settings/`: jendela pengaturan.
- `modules/ai/`: antarmuka Cloud AI.
- `modules/power/` dan `modules/process/`: prototipe yang belum dimuat oleh `shell.qml`.
- `scripts/`: helper Python dan shell untuk integrasi eksternal.
- `assets/`: aset font.
- `tools/`: pemeriksaan statis dan tes lokal.
- `user-settings.json`: pengaturan UI persisten, bukan tempat menyimpan rahasia.

## Pedoman implementasi

- Baca kode terkait, `README.md`, dan catatan kompatibilitas atau hotfix yang
  relevan sebelum mengubah perilaku. Catatan hotfix bersifat historis; cocokkan
  dengan implementasi saat ini.
- Gunakan API yang sesuai dengan baseline Quickshell 0.3.1. Jangan menaikkan
  kebutuhan versi tanpa menjelaskan dampaknya.
- Ikuti gaya QML yang ada: indentasi empat spasi, nama komponen `PascalCase`,
  serta properti dan fungsi `camelCase`.
- Gunakan token `config/Theme.qml` dan font dari `config/Fonts.qml` untuk menjaga
  konsistensi warna, ukuran, jarak, dan tipografi.
- Tempatkan state UI bersama di `config/Store.qml`, pengaturan persisten di
  `config/SettingsStore.qml`, dan state komponen lokal di komponen itu sendiri.
- Perbarui `config/qmldir` atau `services/qmldir` ketika menambah atau mengganti
  tipe yang didaftarkan di direktori tersebut.
- Utamakan layanan native Quickshell yang sudah digunakan untuk jaringan,
  Bluetooth, dan baterai. Hindari polling shell tambahan jika layanan native
  menyediakan data yang dibutuhkan.
- Pertahankan pemilihan layar untuk panel, perilaku buka/tutup, dan dukungan
  hotplug monitor. Hindari binding loop pada layout dan ukuran implisit.
- Tangani perangkat yang tidak tersedia, jaringan terputus, serta kegagalan
  layanan dengan state UI yang jelas dan fallback yang sesuai.
- Jangan menyimpan API key, password Wi-Fi, atau rahasia lain dalam source,
  `user-settings.json`, maupun log. Ikuti mekanisme kredensial yang sudah ada.
- Batasi perubahan pada kebutuhan tugas dan jangan menimpa perubahan pengguna
  yang tidak terkait.

## Menjalankan dan memverifikasi

Jalankan dari root repositori dalam sesi Hyprland yang sesuai:

```bash
qs --version
qs -p .
```

Gunakan `qs log` untuk memeriksa error runtime. Dependensi desktop mencakup
dukungan Hyprland dan Networking pada Quickshell, NetworkManager, BlueZ, serta
UPower. Lihat `README.md` untuk dependensi fitur opsional.

Jalankan pemeriksaan yang relevan dengan perubahan:

```bash
python3 tools/verify-static.py     # Struktur QML, import, registrasi, dan invariant UI
python3 tools/check-bar-modes.py   # Mode bar, persistensi, dan geometri kartu
python3 tools/test_cloud_ai.py     # Kontrak Cloud AI dengan mock, tanpa request jaringan
```

Pemeriksaan statis tidak menggantikan pengujian runtime. Untuk perubahan UI,
periksa bagian yang terdampak: workspace, mode bar, panel, pengaturan, fallback
data, dan perilaku pada beberapa monitor. Untuk perubahan layanan, periksa
interaksi perangkat yang relevan dalam sesi desktop pengguna.

Untuk perubahan dokumentasi saja, periksa isi dan diff; tes runtime tidak
diperlukan. Saat melaporkan hasil, sebutkan perubahan, pemeriksaan yang benar-benar
dijalankan, dan keterbatasan verifikasi. Jangan mengklaim pengujian desktop
berhasil jika hanya menjalankan pemeriksaan statis.
