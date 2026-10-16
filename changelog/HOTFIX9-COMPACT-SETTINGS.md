# Hotfix 9 — Alignment Settings dan Compact

Target: Quickshell 0.3.1, Qt 6, Hyprland. Melanjutkan Hotfix 8.

## Perubahan

- **Visible modules**: kolom ikon dan status masing-masing memiliki lebar tetap
  24px. Judul dan deskripsi rata kiri, mengisi kolom teks, dan memakai elipsis
  bila ruang terbatas. Posisi teks tetap sama untuk ketiga modul.
- **Compact**: tombol workspace, pill indikator, pill informasi, dan tombol
  Quick Settings memiliki tinggi 24px dengan pusat vertikal yang sama. Pill
  informasi menggabungkan cuaca, jam, dan tanggal beserta ikon, memakai latar
  tema dan inset horizontal 8px. Toggle Weather tetap mengatur visibilitas cuaca.
- **Clean Compact**: pilihan baru di Settings → Bar & modules → Bar layout mode,
  disimpan sebagai `clean-compact`. Mengikuti ukuran Compact dengan latar tombol
  Arch, workspace, pill informasi, dan indikator yang transparan. Workspace
  aktif ditandai warna teks aksen. Tombol garis Quick Settings tetap memiliki
  latar dan penanda saat panel terbuka.
- **Spacing Clean Compact**: indikator sistem tidak memiliki padding pill yang
  kosong; ikon memakai slot 18px, jarak antarindikator 10px, dan jarak antargrup
  pada bar 10px. Teks detail Wi-Fi/Bluetooth saat hover tetap tersedia.
- **Ikon informasi**: cuaca, jam, dan tanggal pada kedua mode Compact memakai
  slot ikon 18px, jarak ikon ke teks 6px, dan jarak antargrup informasi 12px.
  Ketiga label memakai font 12px dan berada di tengah vertikal yang sama.

Mode Separated, Professional, dan Simple tetap tersedia. Jam pada mode tersebut
tetap memakai tampilan sebelumnya tanpa tanggal tambahan. Data jam dan tanggal
berasal dari `SystemClock`, sedangkan cuaca tetap memakai `WeatherService`.

## Verifikasi

Pemeriksaan yang dijalankan:

```bash
python3 tools/verify-static.py
python3 tools/check-bar-modes.py
git diff --check
```

Uji layout offscreen pada salinan sementara memverifikasi alignment teks
Settings pada lebar 1100px dan 760px, pemuatan serta penyimpanan `clean-compact`,
transparansi tombol, spacing indikator, tinggi dan pusat vertikal kontrol,
serta batas kanan bar. Preview Settings dan kedua mode Compact juga diperiksa.
Untuk uji ini, wadah PanelWindow diganti sementara dengan FloatingWindow dan
cuaca menggunakan fixture lokal. Integrasi panel Wayland dan perpindahan
workspace Hyprland belum diuji oleh pemeriksaan offscreen tersebut.

Pemeriksaan desktop yang relevan: ganti Compact ↔ Clean Compact, toggle Weather
dan System indicators, hover Wi-Fi/Bluetooth, pindah workspace, buka/tutup Quick
Settings, lalu restart untuk memeriksa persistensi mode. Uji juga pada beberapa
monitor dan bandingkan ketiga mode lama bila digunakan.
