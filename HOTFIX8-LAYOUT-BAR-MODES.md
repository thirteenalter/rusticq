# Hotfix 8 — Konsistensi Quick Control & Mode Bar

Target: Quickshell 0.3.1, Arch Linux + Hyprland. Base: Hotfix 7.

## Audit dan perbaikan

1. **Battery tidak rata**: sebelumnya memakai koordinat `x/y` sementara Wi-Fi memakai `ColumnLayout`. Sekarang Battery memakai `ColumnLayout` dengan inset 16px, header 36px, gap 12px, dan body `Flickable`. Status, indikator level, profil daya memakai ukuran font dan padding seragam. Sisa baterai tidak lagi menampilkan estimasi discharge ketika status fully charged.
2. **Bluetooth tidak konsisten**: kini memakai geometri section yang sama dengan Wi-Fi dan Battery; header yang bisa diklik, switch 40×22, dan daftar perangkat yang bisa di-scroll.
3. **Wi-Fi tampak berbeda**: background baris jaringan menggunakan `Theme.surface`, radius `Theme.rowRadius`, ukuran teks berdasarkan token. Input password memiliki placeholder dan empty state dengan ikon + pesan. Tinggi collapse menggunakan 68px sama dengan Battery/Bluetooth.
4. **System**: tetap permanen, header dan inset disejajarkan (16px; header 36px). Nilai used/total dan free GiB dipertahankan.
5. **Desain konsisten**: token di `config/Theme.qml` untuk section padding, radius, font title/body/helper. Semua tetap Gruvbox Dark + Poppins + Google Material Symbols.

## Bar modes

Masuk ke **Full Settings → Bar & modules → Bar layout mode**, pilih:

- **Compact** — tinggi 36px, margin top 5px, spacing rapat, kontrol fungsional yang sama.
- **Separated** — tinggi 40px, dua pill/island (kiri Arch + workspaces; kanan status + Quick Control), top 10px.
- **Professional** — tinggi 44px, edge-to-edge ber-background Gruvbox, label tengah jika tersedia ruang, panel selalu di atas.
- **Simple** — tinggi 38px; hanya Arch kiri, jam tepat tengah, dan tombol Quick Control kanan. Komponen tambahan tidak dihapus; muncul kembali pada mode lainnya.

Perubahan diterapkan langsung ke `modules/main/Bar.qml` dan disimpan dalam `user-settings.json` lewat singleton `SettingsStore.barMode`. Pilihan module visibility (weather/workspaces/indicators) tetap tersimpan terpisah. Semua mode tetap memiliki Arch AI kiri dan Quick Control kanan.

## Pengujian di perangkat

1. **Jalankan test di path terpisah** agar file konfigurasi lama tidak tertimpa: `qs -p ./quickshell` dari folder hasil extract.
2. Buka Quick Control. Lihat bahwa header Wi-Fi/Bluetooth/Battery punya baseline yang sama, jarak ikon dan teks sama, dan System tidak bisa collapse.
3. Expand Battery, scroll sampai tiga pilihan profil, coba ubah profil (jika backend power-profiles tersedia).
4. Expand Wi-Fi, cek daftar jaringan, placeholder password pada network secure, pesan kosong jika scan tidak menemukan jaringan.
5. Full Settings → Bar & modules: ganti Compact, Separated, Professional, Simple; pastikan tinggi/margin/kelompok kontrol berubah *langsung*.
6. Tutup dan buka lagi `qs`. Pilihan bar mode harus tersimpan di `user-settings.json`.
7. Tes dengan monitor lain bila tersedia, cek semua bar dan sidebar.

Jika panel tidak muncul atau error, cek `qs log -f` dan kirim log. Perubahan telah lolos validasi statis (bukan runtime Wayland).

## Catatan kompatibilitas

- Pada layar sangat sempit, bar dalam mode selain Simple dapat menjadi padat; gunakan Simple bila kontrol bertumpuk.
- File konfigurasi lama tanpa properti `barMode` menggunakan default `separated`.
- API yang digunakan tetap versi Quickshell **0.3.1**: PanelWindow, QtQuick.Layouts, dan FileView. Tidak memerlukan upgrade Quickshell.
- Backend Wi-Fi, Bluetooth, Battery, System, AI cloud tetap berasal dari Hotfix 7 tanpa perubahan mekanisme koneksi.
