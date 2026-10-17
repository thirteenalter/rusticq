# RusticQ Alpha 4 RC3

## Tujuan

Pembaruan layout, branding, pengaturan tampilan, dan AI workspace dengan tetap
mempertahankan desain Gruvbox/Follow Aether dan kompatibilitas Quickshell 0.3.1.

## Fitur

- **App Launcher:** SVG RusticQ menjadi ikon header launcher (ketika brand icon
  aktif). Kotak input pencarian tetap memakai Material Symbols `search` (magnifying
  glass). Badge brand kecil yang sebelumnya ganda di header dihapus.
- **Appearance:** Font Poppins / Sans / Monospace, skala UI 85–120%, kepadatan
  compact/comfortable, dan wallpaper local path dengan preview.
- **Wallpaper backend:** `swww`, `awww`, `hyprpaper` atau otomatis, dipanggil
  via Python tanpa shell injection. Aether palette watcher tetap terpisah.
- **Bar Center:** Zone Center absolut terhadap monitor, bukan dihitung dari
  lebar Left/Right. Offset -280 hingga +280px (step 5px). Ketika absolute
  dimatikan, kembali ke center berbasis flexible layout.
- **Quick Control:** Menggunakan layout khusus `modules/quickcontrol/`, bukan
  berbagi controller BarMain. Tinggi panel dibatasi sampai 690px dan sistem
  memakai presentasi ringkas. Wi-Fi awalnya tertutup agar panel tidak terlalu
  panjang; dropdown dan reorder tetap bisa dibuka kapan saja.
- **AI:** Sidebar dapat diperluas menjadi layar penuh dengan tombol header,
  lengkap dengan daftar thread, new chat, ganti/hapus chat, mode Markdown,
  status provider, dan composer. Percakapan tetap ada saat sidebar ditutup
  dalam satu sesi shell. Pesan **tidak otomatis disimpan ke disk**.

## Pengaturan baru yang persisten di `user-settings.json`

- `absoluteCenter`, `centerOffsetX`
- `uiFontFamily`, `uiFontScale`, `uiDensity`
- `wallpaperPath`, `wallpaperBackend`

Nilai lama dimigrasikan secara aman; tidak ada API key dalam settings JSON.

## Runtime dan batasan

- Butuh Quickshell 0.3.1, Qt 6, Hyprland dan Python 3.
- Wallpaper manual memerlukan daemon wallpaper yang **sudah terpasang dan
  berjalan**; tombol hanya menerapkan saat diminta pengguna.
- Riwayat chat AI hanya hidup di memori selama shell berjalan. Fitur sinkronisasi,
  rename manual dan persistensi history terproteksi belum tersedia.
- Markdown di chat mengikuti kemampuan Qt Quick Text dan memblok preview
  gambar Markdown jarak jauh secara otomatis.

## Smoke test

1. `qs -p ./quickshell`.
2. Settings → Appearance: cek warna, font, scale, wallpaper preview.
3. Settings → Bar: pindahkan Wi-Fi ke Center; klik Absolute Center dan atur offset.
4. Quick Control: cek collapsed Wi-Fi, System tetap terlihat dan bisa di-scroll.
5. Klik AI → expand: buat dua percakapan dan uji Markdown respons.
6. Pastikan mode bar yang lain, mini-widget, dan popup notifikasi tetap bekerja.
