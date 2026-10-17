# RusticQ Alpha 4 RC2 — Branding, Professional Mode & Vertical Bar Fix

## Ringkasan
Pembaruan ini mulai memasukkan branding RusticQ yang baru ke beberapa area utama, sekaligus merapikan konsistensi mode bar — terutama Professional — dan menyederhanakan indikator pada posisi bar Left / Right.

## Perubahan utama

### Branding RusticQ baru
- Menambahkan aset baru `assets/rusticq-icon.svg`.
- Menambahkan komponen reusable `components/RusticQIcon.qml`.
- Mengganti ikon utama pada header Settings menjadi SVG RusticQ.
- Menambahkan branding RusticQ pada halaman **About** beserta visual image/logo.
- Mengganti ikon launcher utama di bar menggunakan ikon RusticQ.
- Menambahkan ikon RusticQ pada header launcher dan pada field pencariannya.
- Menyesuaikan shortcut Dock untuk **Launcher** dan **Settings** agar mendukung ikon RusticQ.

### Konsistensi bar mode
- Merapikan spacing dan margin internal mode **Professional** agar lebih selaras dengan mode lain.
- Menyesuaikan lebar vertical bar ketika mode Professional aktif agar tidak terlalu lebar.
- Menjaga pola visual yang lebih konsisten antara Top / Bottom dan Left / Right.

### Vertical bar (Left / Right)
- Khusus indikator **Battery** dan **Audio/Volume**, posisi bar Left / Right sekarang menampilkan **ikon saja**.
- Popup detail tetap bisa diakses saat ikon diklik.
- Persentase baterai dan volume tetap tampil di bar horizontal.

## File yang berubah
- `assets/rusticq-icon.svg`
- `components/RusticQIcon.qml`
- `components/Battery.qml`
- `components/Audio.qml`
- `components/BarZone.qml`
- `modules/main/Bar.qml`
- `modules/main/MiniLauncher.qml`
- `modules/main/RusticDock.qml`
- `modules/settings/SettingsWindow.qml`
- `modules/settings/pages/SettingsAboutPage.qml`

## Catatan
Perubahan ini tetap mempertahankan versi proyek pada **RusticQ Alpha 4 RC2**.
